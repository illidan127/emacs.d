;;; -*- lexical-binding: t -*-

;;; Magit 提交前通过 agent-shell 生成 commit message。

(require 'cl-lib)

(declare-function agent-shell-buffers "agent-shell")
(declare-function agent-shell-cwd "agent-shell")
(declare-function agent-shell-insert "agent-shell")
(declare-function agent-shell-project-buffers "agent-shell")
(declare-function agent-shell-subscribe-to "agent-shell")
(declare-function agent-shell-unsubscribe "agent-shell")
(declare-function agent-shell--shell-buffer "agent-shell")
(declare-function eon--ensure-git-user-identity "eon-vcs")
(declare-function eon-insert-commit-class "eon-vcs")
(declare-function git-commit-setup "git-commit")
(declare-function magit-commit-message-buffer "magit-commit")
(declare-function magit-commit-assert "magit-commit")
(declare-function magit-commit-create "magit-commit")
(declare-function magit-toplevel "magit-git")
(declare-function shell-maker-busy "shell-maker")

(defvar git-commit-filename-regexp)
(defvar agent-shell--transcript-file)

(defgroup eon-magit-agent-commit nil
  "Magit 提交时通过 agent-shell 生成 commit message。"
  :group 'eon)

(defcustom eon-magit-agent-commit-auto t
  "Magit 创建提交（c c）时，先向 agent-shell 请求 commit message，再打开编辑 buffer。"
  :group 'eon-magit-agent-commit
  :type 'boolean)

(defvar eon-magit-agent-commit--commit-buffer nil)
(defvar eon-magit-agent-commit--draft-message nil
  "AI 预生成的 commit message，在 COMMIT_EDITMSG 打开后写入。")
(defvar eon-magit-agent-commit--deferred-commit nil
  "AI 回复后执行的 Magit 提交函数。")
(defvar eon-magit-agent-commit--pending-p nil
  "为 t 时禁止 C-c C-c 完成提交，等待 agent 回复。")
(defvar eon-magit-agent-commit--subscription nil)

(defun eon-magit-agent-commit--visit-commit-file-p ()
  "当前 buffer 是否正在编辑 Git commit message 文件。"
  (and buffer-file-name
       (require 'git-commit nil t)
       (boundp 'git-commit-filename-regexp)
       (string-match-p git-commit-filename-regexp buffer-file-name)))

(defun eon-magit-agent-commit--git-commit-mode-active-p ()
  (eq t (ignore-errors
          (buffer-local-value 'git-commit-mode (current-buffer)))))

(defun eon-magit-agent-commit--commit-buffer-p ()
  "当前 buffer 是否为 Magit/with-editor 打开的 Git 提交 message buffer。"
  (or (eon-magit-agent-commit--git-commit-mode-active-p)
      (and with-editor-mode (eon-magit-agent-commit--visit-commit-file-p))))

(defun eon-magit-agent-commit--ensure-git-commit-setup ()
  "Magit 复用 COMMIT_EDITMSG buffer 时补跑 `git-commit-setup'。

with-editor 通过 `find-file-noselect' 打开已有 buffer 时不会再次触发
`find-file-hook'；若 buffer 仍保留 `git-commit-mode'，setup hook 也不会重跑，
导致用户身份选择与 AI 草稿均丢失。"
  (when (and (eon-magit-agent-commit--visit-commit-file-p)
             (or (not (eon-magit-agent-commit--git-commit-mode-active-p))
                 eon-magit-agent-commit--draft-message))
    (git-commit-setup)))

(defun eon-magit-agent-commit--reset-state ()
  (setq eon-magit-agent-commit--pending-p nil)
  (eon-magit-agent-commit--cleanup-subscription))

(defun eon-magit-agent-commit--cancel-prefetch ()
  (setq eon-magit-agent-commit--deferred-commit nil
        eon-magit-agent-commit--draft-message nil)
  (eon-magit-agent-commit--reset-state))

(defun eon-magit-agent-commit--reuse-message-p (args)
  (and args
       (seq-find (lambda (arg)
                   (and (stringp arg)
                        (string-prefix-p "--reuse-message=" arg)))
                 args)))

(defun eon-magit-agent-commit--should-prefetch-p (args)
  (and eon-magit-agent-commit-auto
       (not eon-magit-agent-commit--deferred-commit)
       (not (eon-magit-agent-commit--reuse-message-p args))
       (and (fboundp 'eon-workspace-current)
            (eon-workspace-current))
       (condition-case err
           (eon-magit-agent-commit--shell-for-repo)
         (error (signal (car err) (cdr err))))))

(defun eon-magit-agent-commit--complete-prefetch (&optional message)
  "AI 预生成结束：保存 draft，再打开 COMMIT_EDITMSG buffer。"
  (setq eon-magit-agent-commit--pending-p nil
        eon-magit-agent-commit--draft-message message)
  (when-let ((commit-fn (prog1 eon-magit-agent-commit--deferred-commit
                          (setq eon-magit-agent-commit--deferred-commit nil))))
    (funcall commit-fn)
    ;; visit hook 未消费 draft 时再补跑 setup（例如极端 buffer 复用场景）
    (when eon-magit-agent-commit--draft-message
      (when-let ((buf (eon-magit-agent-commit--resolve-commit-buffer)))
        (with-current-buffer buf
          (git-commit-setup))))))

(defun eon-magit-agent-commit--send-agent-request (shell &optional commit-buffer prompt-override)
  (require 'agent-shell)
  (let ((prompt (or prompt-override (eon-magit-agent-commit--build-prompt))))
    (when commit-buffer
      (setq eon-magit-agent-commit--commit-buffer commit-buffer))
    (setq eon-magit-agent-commit--pending-p t)
    (eon-magit-agent-commit--cleanup-subscription)
    (setq eon-magit-agent-commit--subscription
          (agent-shell-subscribe-to
           :shell-buffer shell
           :event 'turn-complete
           :on-event (lambda (event)
                       (eon-magit-agent-commit--on-turn-complete event shell))))
    (agent-shell-insert :text prompt :submit t :no-focus t :shell-buffer shell)))

(cl-defun eon-magit-agent-commit--prefetch-message ()
  "向 agent-shell 请求 commit message；完成后调用 `eon-magit-agent-commit--deferred-commit'。"
  (let* ((root (eon-magit-agent-commit--repo-root))
         (shell (condition-case nil
                    (eon-magit-agent-commit--shell-for-repo root)
                  (error nil))))
    (unless shell
      (message "未找到 agent-shell，跳过 AI 预生成")
      (eon-magit-agent-commit--complete-prefetch nil)
      (cl-return nil))
    (when (with-current-buffer shell (shell-maker-busy))
      (message "agent-shell 忙碌中，跳过 AI 预生成")
      (eon-magit-agent-commit--complete-prefetch nil)
      (cl-return nil))
    (message "正在向 agent-shell 请求提交信息…")
    (eon-magit-agent-commit--send-agent-request shell)))

(defun eon-magit-agent-commit--repo-root ()
  (or (ignore-errors (magit-toplevel))
      (when (and default-directory (file-directory-p default-directory))
        (directory-file-name (expand-file-name default-directory)))))

(defun eon-magit-agent-commit--normalize-dir (dir)
  (when dir (file-name-as-directory (expand-file-name dir))))

(defun eon-magit-agent-commit--shell-cwd (buf)
  (with-current-buffer buf
    (when (derived-mode-p 'agent-shell-mode)
      (eon-magit-agent-commit--normalize-dir (agent-shell-cwd)))))

(defun eon-magit-agent-commit--shell-for-repo (&optional root)
  "返回与 ROOT（或当前仓库）匹配的 agent-shell buffer。

若当前处于工作区窗口中，则强制要求 agent-shell 的 cwd 与仓库根目录
一致，否则报错中止。非工作区窗口则沿用宽松匹配策略。"
  (require 'agent-shell)
  (let* ((root (eon-magit-agent-commit--normalize-dir
                (or root (eon-magit-agent-commit--repo-root))))
         (shells (agent-shell-buffers))
         (exact (when root
                  (seq-find (lambda (buf)
                              (equal root (eon-magit-agent-commit--shell-cwd buf)))
                            shells)))
         (in-workspace (and (fboundp 'eon-workspace-current)
                            (eon-workspace-current))))
    (if in-workspace
        (or exact
            (user-error "当前工作区未找到仓库 %s 对应的 agent-shell，请先用 F8 打开工作区并在其中启动 agent"
                        root))
      (or exact
          (when (fboundp 'agent-shell-project-buffers)
            (let ((default-directory (or root default-directory)))
              (seq-first (agent-shell-project-buffers))))
          (when root
            (seq-find
             (lambda (buf)
               (let ((cwd (eon-magit-agent-commit--shell-cwd buf)))
                 (when cwd
                   (or (string-prefix-p cwd root)
                       (string-prefix-p root cwd)))))
             shells))
          (when (and eon-magit-agent-commit-auto shells)
            (car shells))
          (when root
            (let ((default-directory root))
              (agent-shell--shell-buffer :no-create t :no-error t)))))))

(defun eon-magit-agent-commit--staged-diff ()
  (let ((default-directory (or (eon-magit-agent-commit--repo-root) default-directory)))
    (string-trim (or (shell-command-to-string "git diff --cached") ""))))

(defun eon-magit-agent-commit--recent-log ()
  (let ((default-directory (or (eon-magit-agent-commit--repo-root) default-directory)))
    (string-trim (or (shell-command-to-string "git log -5 --oneline") ""))))

(defun eon-magit-agent-commit--build-prompt ()
  (let* ((diff (eon-magit-agent-commit--staged-diff))
         (log (eon-magit-agent-commit--recent-log))
         (diff-text (if (string-empty-p diff) "(无暂存变更)" diff)))
    (format (concat "请为以下 git 暂存区变更生成一条提交信息。\n\n"
                    "要求：\n"
                    "1. 仅输出提交信息正文，严禁包含任何前缀（如 feat:、fix:、[配置]: 等），前缀将由用户后续手动选择\n"
                    "2. 使用简洁中文描述变更内容及目的，风格参考最近提交记录\n"
                    "3. 标题控制在 50 字以内，确需补充说明时空一行再写正文\n\n"
                    "最近提交记录：\n```\n%s\n```\n\n"
                    "暂存区变更：\n```diff\n%s\n```")
            log diff-text)))

(defun eon-magit-agent-commit--strip-fences (text)
  (when (and text (not (string-empty-p (string-trim text))))
    (let* ((trimmed (string-trim text))
           (fence (concat (char-to-string ?`) (char-to-string ?`) (char-to-string ?`))))
      (if (string-prefix-p fence trimmed)
          (let ((lines (split-string trimmed "\n")))
            (when (> (length lines) 2)
              (string-trim (string-join (butlast (cdr lines)) "\n"))))
        trimmed))))

(defvar eon-magit-agent-commit--simplify-retry nil
  "非 nil 表示当前正在等待 LLM 简化标题。
值为上一轮的原始 message，用于合并正文。")

(defun eon-magit-agent-commit--title-too-long-p (message)
  "判断 MESSAGE 首行是否超过 50 字。"
  (when (and message (not (string-empty-p (string-trim message))))
    (let ((first (car (split-string message "\n"))))
      (> (string-width first) 50))))

(defun eon-magit-agent-commit--request-simplify (message shell-buffer)
  "向 agent 请求简化 MESSAGE 标题。"
  (setq eon-magit-agent-commit--simplify-retry message)
  (eon-magit-agent-commit--send-agent-request
   shell-buffer
   nil                               ; 不记录 commit-buffer
   (format (concat "以下提交信息标题超过 50 字，请将其简化。\n"
                   "要求：仅输出简化后的提交信息正文，严禁任何前缀或解释性文字，\n"
                   "标题控制 50 字以内，确需补充说明时空一行再写正文。\n\n"
                   "```\n%s\n```")
           message)))

(defun eon-magit-agent-commit--resolve-commit-buffer ()
  "返回当前仓库的 git commit message buffer，必要时更新缓存。"
  (let ((buf
         (or (when (and eon-magit-agent-commit--commit-buffer
                        (buffer-live-p eon-magit-agent-commit--commit-buffer)
                        (with-current-buffer eon-magit-agent-commit--commit-buffer
                          (eon-magit-agent-commit--commit-buffer-p)))
               eon-magit-agent-commit--commit-buffer)
             (when (fboundp 'magit-commit-message-buffer)
               (magit-commit-message-buffer))
             (when (and buffer-file-name
                        (eon-magit-agent-commit--visit-commit-file-p)
                        (eon-magit-agent-commit--commit-buffer-p))
               (current-buffer)))))
    (when buf
      (setq eon-magit-agent-commit--commit-buffer buf))
    buf))

(defun eon-magit-agent-commit--extract-agent-section (text)
  (when (and text (not (string-empty-p (string-trim text))))
    (with-temp-buffer
      (insert text)
      (goto-char (point-max))
      (when (re-search-backward "^## Agent (" nil t)
        (forward-line 1)
        (let* ((start (point))
               (end (save-excursion
                      (if (re-search-forward
                           "^\\(?:## \\|### Tool Call\\|---\\)" nil t)
                          (match-beginning 0)
                        (point-max))))
               (body (buffer-substring-no-properties start end)))
          (eon-magit-agent-commit--strip-fences (string-trim body)))))))

(defun eon-magit-agent-commit--last-agent-message-from-file (file)
  (when (and file (file-readable-p file))
    (eon-magit-agent-commit--extract-agent-section
     (with-temp-buffer
       (insert-file-contents file)
       (buffer-string)))))

(defun eon-magit-agent-commit--last-agent-message (shell-buffer)
  (with-current-buffer shell-buffer
    (or (when (and (boundp 'agent-shell--transcript-file)
                   agent-shell--transcript-file)
          (eon-magit-agent-commit--last-agent-message-from-file
           agent-shell--transcript-file))
        (eon-magit-agent-commit--extract-agent-section
         (buffer-substring-no-properties (point-min) (point-max))))))

(defun eon-magit-agent-commit--insert-body (message)
  (when (and message (not (string-empty-p (string-trim message))))
    (let ((commit-buf (eon-magit-agent-commit--resolve-commit-buffer)))
      (when commit-buf
        (with-current-buffer commit-buf
          (goto-char (point-min))
          (let ((comment-beg
                 (save-excursion
                   (if (re-search-forward
                        (format "^%s" (regexp-quote comment-start)) nil t)
                       (match-beginning 0)
                     (point-max)))))
            (delete-region (point-min) comment-beg)
            (insert message)
            (unless (string-suffix-p "\n" message) (insert "\n"))
            (save-excursion
              (goto-char (point-min))
              (when (and (search-forward "\n" nil t)
                         (not (eobp))
                         (not (eq (char-after) ?\n)))
                (insert "\n")))
            (insert "\n")
            (save-buffer))
        (pop-to-buffer commit-buf))))))

(defun eon-magit-agent-commit--run-commit-class ()
  "弹出 commit-class 选择器，在 subject 前插入前缀。"
  (when (and (eon-magit-agent-commit--resolve-commit-buffer)
             (fboundp 'eon-insert-commit-class))
    (with-current-buffer eon-magit-agent-commit--commit-buffer
      (require 'eon-vcs)
      (call-interactively 'eon-insert-commit-class))))

(defun eon-magit-agent-commit--finish-ai-flow (&optional message)
  "结束 AI 流程：插入 message（若有），再选择 commit-class。"
  (setq eon-magit-agent-commit--pending-p nil)
  (when (eon-magit-agent-commit--resolve-commit-buffer)
    (when message
      (eon-magit-agent-commit--insert-body message))
    (eon-magit-agent-commit--run-commit-class)
    (message "AI 提交信息已就绪，请编辑后 C-c C-c 确认")))

(defun eon-magit-agent-commit--cleanup-subscription ()
  (when eon-magit-agent-commit--subscription
    (agent-shell-unsubscribe :subscription eon-magit-agent-commit--subscription)
    (setq eon-magit-agent-commit--subscription nil)))

(defun eon-magit-agent-commit--on-turn-complete (event shell-buffer)
  (let ((stop-reason (map-elt (map-elt event :data) :stop-reason)))
    (eon-magit-agent-commit--cleanup-subscription)
    (if (equal stop-reason "end_turn")
        (let ((msg (eon-magit-agent-commit--last-agent-message shell-buffer)))
          (cond
           ;; 简化重试返回的消息：直接使用，不再检查长度以防死循环
           (eon-magit-agent-commit--simplify-retry
            (setq eon-magit-agent-commit--simplify-retry nil)
            (if eon-magit-agent-commit--deferred-commit
                (progn
                  (unless msg
                    (message "Agent 回复为空，将打开空白提交 buffer"))
                  (eon-magit-agent-commit--complete-prefetch msg))
              (if msg
                  (eon-magit-agent-commit--finish-ai-flow msg)
                (progn
                  (message "Agent 回复为空，请选择 commit-class 后手动编写")
                  (eon-magit-agent-commit--finish-ai-flow nil)))))
           ;; 首次生成：标题超长 → 发回 LLM 简化
           ((and msg (eon-magit-agent-commit--title-too-long-p msg))
            (message "提交信息标题超 50 字，正在请求 AI 简化…")
            (eon-magit-agent-commit--request-simplify msg shell-buffer))
           ;; 正常：标题合规或无消息
           (t
            (if eon-magit-agent-commit--deferred-commit
                (progn
                  (unless msg
                    (message "Agent 回复为空，将打开空白提交 buffer"))
                  (eon-magit-agent-commit--complete-prefetch msg))
              (if msg
                  (eon-magit-agent-commit--finish-ai-flow msg)
                (progn
                  (message "Agent 回复为空，请选择 commit-class 后手动编写")
                  (eon-magit-agent-commit--finish-ai-flow nil)))))))
      (if eon-magit-agent-commit--deferred-commit
          (progn
            (message "Agent 未完成回复（%s），将打开空白提交 buffer"
                     (or stop-reason "unknown"))
            (eon-magit-agent-commit--complete-prefetch nil))
        (progn
          (message "Agent 未完成回复（%s）" (or stop-reason "unknown"))
          (setq eon-magit-agent-commit--pending-p nil)
          (eon-magit-agent-commit--run-commit-class))))))

(defun eon-magit-agent-commit--finish-query (force)
  "等待 agent 生成提交信息期间阻止 C-c C-c。"
  (or force
      (not eon-magit-agent-commit--pending-p)
      (progn
        (message "等待 AI 生成提交信息，请稍候…（强制提交请 C-u C-c C-c）")
        nil)))

(defun eon-magit-agent-commit-request ()
  "向当前工作区的 agent-shell 请求 commit message，完成后插入并选择 commit-class。"
  (interactive)
  (unless (eon-magit-agent-commit--commit-buffer-p)
    (user-error "请在 Git 提交 message buffer 中使用"))
  (let* ((root (eon-magit-agent-commit--repo-root))
         (shell (eon-magit-agent-commit--shell-for-repo root)))
    (unless shell
      (user-error "未找到仓库 %s 对应的 agent-shell，请先在工作区启动 agent"
                  (or root default-directory)))
    (when (with-current-buffer shell (shell-maker-busy))
      (user-error "agent-shell 忙碌中，请稍后再试"))
    (message "已向 agent-shell 请求提交信息…")
    (eon-magit-agent-commit--send-agent-request shell (current-buffer))))

(defun eon-magit-agent-commit--invoked-by-key-p ()
  "判断当前 `magit-commit-create' 是否通过快捷键（而非 M-x）调用。

通过 M-x 调用时，触发命令的最后一个输入事件是 RET（回车确认
minibuffer）；通过 Magit transient 菜单的 c c 或其他按键序列调用时，
最后一个事件是对应的按键。"
  (let ((event last-command-event))
    (and event
         (not (and (integerp event)
                   (or (= event ?\r)     ; RET
                       (= event ?\n))))))) ; LFD

(cl-defun eon-magit-agent-commit--magit-commit-create (orig &optional args)
  "先 AI 预生成提交信息，再调用 `magit-commit-create' 打开 COMMIT_EDITMSG。

仅当通过快捷键调用时才触发 AI 预生成；通过 M-x 调用时直接打开提交
buffer，由用户自行编写提交信息。"
  (let ((default-directory (magit-toplevel)))
    (require 'eon-vcs)
    (unless (eon--ensure-git-user-identity)
      (eon-magit-agent-commit--cancel-prefetch)
      (cl-return-from eon-magit-agent-commit--magit-commit-create nil))
    (if (and (eon-magit-agent-commit--invoked-by-key-p)
             (eon-magit-agent-commit--should-prefetch-p args))
        (progn
          (unless (setq args (magit-commit-assert args))
            (cl-return-from eon-magit-agent-commit--magit-commit-create nil))
          (setq eon-magit-agent-commit--deferred-commit
                (lambda () (funcall orig args)))
          (eon-magit-agent-commit--prefetch-message))
      (funcall orig args))))

(defun eon-magit-agent-commit--setup ()
  "git-commit-setup-hook：写入预生成的 message，再选择 commit-class。"
  (when (eon-magit-agent-commit--commit-buffer-p)
    (setq eon-magit-agent-commit--commit-buffer (current-buffer))
    (let ((buf (current-buffer))
          (draft eon-magit-agent-commit--draft-message))
      (setq eon-magit-agent-commit--draft-message nil)
      (run-at-time 0 nil
                   (lambda ()
                     (when (buffer-live-p buf)
                       (with-current-buffer buf
                         (if draft
                             (eon-magit-agent-commit--finish-ai-flow draft)
                           (eon-magit-agent-commit--run-commit-class)))))))))

(defun eon-magit-agent-commit--register ()
  (require 'eon-vcs)
  (remove-hook 'with-editor-filter-visit-hook
                #'eon-magit-agent-commit--ensure-git-commit-setup)
  (remove-hook 'git-commit-setup-hook #'eon-insert-commit-class-wrapper)
  (remove-hook 'git-commit-setup-hook #'eon-magit-agent-commit--setup)
  (remove-hook 'git-commit-setup-hook #'eon-magit-agent-commit--prepare-auto)
  (remove-hook 'git-commit-setup-hook #'eon-magit-agent-commit--setup-commit-class)
  (remove-hook 'git-commit-setup-hook #'eon-magit-agent-commit--setup-auto)
  (remove-hook 'git-commit-finish-query-functions
                #'eon-magit-agent-commit--finish-query)
  (advice-remove 'magit-commit-create #'eon-magit-agent-commit--magit-commit-create)
  (define-key git-commit-mode-map (kbd "C-c C-a")
              #'eon-magit-agent-commit-request)
  (add-hook 'with-editor-filter-visit-hook
            #'eon-magit-agent-commit--ensure-git-commit-setup)
  (add-hook 'git-commit-setup-hook #'eon-magit-agent-commit--setup 95)
  (add-hook 'git-commit-finish-query-functions
            #'eon-magit-agent-commit--finish-query)
  (advice-add 'magit-commit-create :around #'eon-magit-agent-commit--magit-commit-create))

(with-eval-after-load 'magit-commit
  (eon-magit-agent-commit--register))

(with-eval-after-load 'git-commit
  (eon-magit-agent-commit--register))

(when (and (featurep 'magit-commit) (featurep 'git-commit))
  (eon-magit-agent-commit--register))

(provide 'eon-magit-agent-commit)
