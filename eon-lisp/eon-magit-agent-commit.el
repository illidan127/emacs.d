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
(declare-function eon-insert-commit-class "eon-vcs")
(declare-function git-commit-setup "git-commit")
(declare-function magit-commit-message-buffer "magit-commit")
(declare-function magit-toplevel "magit-git")
(declare-function shell-maker-busy "shell-maker")

(defvar git-commit-filename-regexp)
(defvar agent-shell--transcript-file)

(defgroup eon-magit-agent-commit nil
  "Magit 提交时通过 agent-shell 生成 commit message。"
  :group 'eon)

(defcustom eon-magit-agent-commit-auto t
  "打开 git-commit buffer 时自动向 agent-shell 请求 commit message。"
  :group 'eon-magit-agent-commit
  :type 'boolean)

(defvar eon-magit-agent-commit--commit-buffer nil)
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
`find-file-hook'，导致 `git-commit-mode' 仍为 nil、setup hook 不执行。"
  (when (and (eon-magit-agent-commit--visit-commit-file-p)
             (not (eon-magit-agent-commit--git-commit-mode-active-p)))
    (git-commit-setup)))

(defun eon-magit-agent-commit--reset-state ()
  (setq eon-magit-agent-commit--pending-p nil)
  (eon-magit-agent-commit--cleanup-subscription))

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
  "返回与 ROOT（或当前仓库）匹配的 agent-shell buffer。"
  (require 'agent-shell)
  (let* ((root (eon-magit-agent-commit--normalize-dir
                (or root (eon-magit-agent-commit--repo-root))))
         (shells (agent-shell-buffers))
         (exact (when root
                  (seq-find (lambda (buf)
                              (equal root (eon-magit-agent-commit--shell-cwd buf)))
                            shells)))
         (nested (when root
                   (seq-find
                    (lambda (buf)
                      (let ((cwd (eon-magit-agent-commit--shell-cwd buf)))
                        (when cwd
                          (or (string-prefix-p cwd root)
                              (string-prefix-p root cwd)))))
                    shells))))
    (or exact
        (when (fboundp 'agent-shell-project-buffers)
          (let ((default-directory (or root default-directory)))
            (seq-first (agent-shell-project-buffers))))
        nested
        (when (and eon-magit-agent-commit-auto shells)
          (car shells))
        (when root
          (let ((default-directory root))
            (agent-shell--shell-buffer :no-create t :no-error t))))))

(defun eon-magit-agent-commit--staged-diff ()
  (let ((default-directory (or (eon-magit-agent-commit--repo-root) default-directory)))
    (string-trim (or (shell-command-to-string "git diff --cached") ""))))

(defun eon-magit-agent-commit--recent-log ()
  (let ((default-directory (or (eon-magit-agent-commit--repo-root) default-directory)))
    (string-trim (or (shell-command-to-string "git log -5 --oneline") ""))))

(defun eon-magit-agent-commit--build-prompt ()
  (let* ((diff (eon-magit-agent-commit--staged-diff))
         (log (eon-magit-agent-commit--recent-log))
         (diff-text (if (string-empty-p diff) "(无 staged diff)" diff)))
    (format (concat "请根据以下已 stage 的 git 变更，生成一条 commit message。\n\n"
                    "要求：\n"
                    "- 参考最近 commit 的 subject/body 风格，但不要复制类别前缀\n"
                    "- 不要输出 feat:/fix:/docs: 或 [配置]: 等前缀（用户稍后会单独选择）\n"
                    "- 第一行 subject 简洁；仅在 why 不明显时加 body（空一行后写）\n"
                    "- 只输出 commit message 正文，不要 markdown 代码块，不要额外解释\n"
                    "- 不要执行 git commit，不要修改文件\n\n"
                    "最近 commit：\n%s\n\n"
                    "已 stage diff：\n---\n%s\n---")
            log diff-text)))

(defun eon-magit-agent-commit--strip-fences (text)
  (when (and text (not (string-empty-p (string-trim text))))
    (let* ((trimmed (string-trim text))
           (fence (concat (char-to-string ?`) (char-to-string ?`) (char-to-string ?`))))
      (if (string-prefix-p fence trimmed)
          (let ((lines (split-string trimmed "\n" t)))
            (when (> (length lines) 2)
              (string-trim (string-join (butlast (cdr lines)) "\n"))))
        trimmed))))

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
          (if msg
              (eon-magit-agent-commit--finish-ai-flow msg)
            (progn
              (message "Agent 回复为空，请选择 commit-class 后手动编写")
              (eon-magit-agent-commit--finish-ai-flow nil))))
      (progn
        (message "Agent 未完成回复（%s）" (or stop-reason "unknown"))
        (setq eon-magit-agent-commit--pending-p nil)
        (eon-magit-agent-commit--run-commit-class)))))

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
  (require 'agent-shell)
  (let* ((root (eon-magit-agent-commit--repo-root))
         (shell (eon-magit-agent-commit--shell-for-repo root))
         (prompt (eon-magit-agent-commit--build-prompt)))
    (unless shell
      (setq eon-magit-agent-commit--pending-p nil)
      (user-error "未找到仓库 %s 对应的 agent-shell，请先在工作区启动 agent"
                  (or root default-directory)))
    (when (with-current-buffer shell (shell-maker-busy))
      (user-error "agent-shell 忙碌中，请稍后再试"))
    (setq eon-magit-agent-commit--commit-buffer (current-buffer)
          eon-magit-agent-commit--pending-p t)
    (eon-magit-agent-commit--cleanup-subscription)
    (setq eon-magit-agent-commit--subscription
          (agent-shell-subscribe-to
           :shell-buffer shell
           :event 'turn-complete
           :on-event (lambda (event)
                       (eon-magit-agent-commit--on-turn-complete event shell))))
    (message "已向 agent-shell 请求提交信息…")
    (agent-shell-insert :text prompt :submit t :no-focus t :shell-buffer shell)))

(defun eon-magit-agent-commit--start-after-buffer-ready ()
  "提交 buffer 就绪后：先 AI 生成 message，再 commit-class。"
  (when (eon-magit-agent-commit--commit-buffer-p)
    (setq eon-magit-agent-commit--commit-buffer (current-buffer))
    (let ((shell (condition-case nil
                     (eon-magit-agent-commit--shell-for-repo)
                   (error nil))))
      (if shell
          (condition-case err
              (eon-magit-agent-commit-request)
            (error
             (setq eon-magit-agent-commit--pending-p nil)
             (message "AI 提交信息请求失败：%s" (error-message-string err))
             (eon-magit-agent-commit--run-commit-class)))
        (message "未找到 agent-shell（仓库 %s），仅选择 commit-class"
                 (or (eon-magit-agent-commit--repo-root) default-directory))
        (eon-magit-agent-commit--run-commit-class)))))

(defun eon-magit-agent-commit--setup ()
  "git-commit-setup-hook：仅调度异步任务，避免在 hook 内调用 ivy/agent-shell。"
  (when (eon-magit-agent-commit--commit-buffer-p)
    (eon-magit-agent-commit--reset-state)
    (setq eon-magit-agent-commit--commit-buffer (current-buffer))
    (if eon-magit-agent-commit-auto
        (let ((buf (current-buffer)))
          (run-at-time 0 nil
                       (lambda ()
                         (when (buffer-live-p buf)
                           (with-current-buffer buf
                             (eon-magit-agent-commit--start-after-buffer-ready))))))
      (let ((buf (current-buffer)))
        (run-at-time 0 nil
                     (lambda ()
                       (when (buffer-live-p buf)
                         (with-current-buffer buf
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
  (define-key git-commit-mode-map (kbd "C-c C-a")
              #'eon-magit-agent-commit-request)
  (add-hook 'with-editor-filter-visit-hook
            #'eon-magit-agent-commit--ensure-git-commit-setup)
  (add-hook 'git-commit-setup-hook #'eon-magit-agent-commit--setup 95)
  (add-hook 'git-commit-finish-query-functions
            #'eon-magit-agent-commit--finish-query))

(with-eval-after-load 'with-editor
  (add-hook 'with-editor-filter-visit-hook
            #'eon-magit-agent-commit--ensure-git-commit-setup))

(with-eval-after-load 'git-commit
  (eon-magit-agent-commit--register))

(when (featurep 'git-commit)
  (eon-magit-agent-commit--register))

(provide 'eon-magit-agent-commit)
