;;; -*- lexical-binding: t -*-

;;; 版本控制系统

(require 'eon-git-util)

;; 使用与当前 Emacs 同源的 emacsclient，避免 git 提交时 socket 不匹配
(eval-after-load 'with-editor
  (lambda ()
    (setq-default with-editor-emacsclient-executable
                  (or (with-editor-locate-emacsclient)
                      (when (and (boundp 'invocation-directory)
                                 invocation-directory)
                        (expand-file-name "bin/emacsclient" invocation-directory))
                      "emacsclient"))))

(defun eon-magit-format-file (file)
  "在magit-status界面格式化对应文件"
  (interactive (list (magit-diff--file-at-point t t)))
  (let ((buf (or (get-file-buffer file) (find-file-noselect file))))
    (with-current-buffer buf
      (eon-manual-save-buffer))))


(defface magit-diff-context-highlight
  `((((class color) (background light))
     ,@(and (>= emacs-major-version 27) '(:extend t))
     :background "grey95"
     :foreground "grey50")
    (((class color) (background dark))
     ,@(and (>= emacs-major-version 27) '(:extend t))
     :background "grey5"
     :foreground "grey70"))
  "覆盖magit自带的一些颜色配置，让diff更好看些"
  :group 'magit-faces)


(use-package
  blamer
  :bind (("s-i" . blamer-show-commit-info))
  :custom
  (blamer-idle-time 0)
  (blamer-min-offset 70)
  (blamer-datetime-formatter "%s ")
  (blamer-prettify-time-p nil)
  (blamer-show-avatar-p nil)
  :custom-face
  (blamer-face
   (
    (t
     :foreground "#7a88cf"
     :background "unspecified"
     :height 140
     :italic t))))

(defcustom eon-git-user-identities nil
  "Git 用户身份列表。提交前若当前仓库未配置本地 user.name/user.email 时供选择。"
  :group 'eon
  :type '(alist :key-type string :value-type (cons string string)))

(defcustom eon-git-commit-class
  '(("feat -- 新特性" . "feat: ")
    ("fix -- 修复" . "fix: ")
    ("docs -- 文档" . "docs: ")
    ("style -- 格式" . "style: ")
    ("refactor -- 重构" . "refactor: ")
    ("perf -- 性能" . "perf: ")
    ("test -- 测试" . "test: ")
    ("build -- 构建" . "build: ")
    ("ci -- 持续集成" . "ci: ")
    ("chore -- 杂项" . "chore: ")
    ("revert -- 回滚" . "revert: "))
  "Git 提交类别定义，遵循 Conventional Commits 规范。"
  :group 'eon
  :type '(alist :key-type string :value-type string))

(defun eon--prompt-for-git-user-identity ()
  (let ((result nil)
	(inhibit-quit t))
    (if (null eon-git-user-identities)
	(progn
	  (message "未配置 eon-git-user-identities")
	  nil)
      (unless (with-local-quit
		(ivy-read "选择 Git 用户身份："
			  eon-git-user-identities
			  :caller 'eon--prompt-for-git-user-identity
			  :action #'(lambda (item) (setq result (cdr item)))))
	(message "未选择 Git 用户身份")
	(setq quit-flag nil))
      result)))


(defun eon--ensure-git-user-identity ()
  "确保当前仓库已配置本地 user.name 和 user.email。
若未配置则通过 ivy 选择并写入本地配置。成功返回 t，取消返回 nil。"
  (if (eon-git-util-local-user-identity-configured-p)
      t
    (if-let* ((identity (eon--prompt-for-git-user-identity)))
	(progn
	  (eon-git-util-set-local-user-identity (car identity) (cdr identity))
	  (message "已设置 Git 用户: %s <%s>" (car identity) (cdr identity))
	  t)
      nil)))


(defun eon-commit-classes-for-host--default (_host _repo-name)
  "默认提交类别选择函数，始终返回 `eon-git-commit-class'。"
  eon-git-commit-class)


(defcustom eon-commit-classes-for-host #'eon-commit-classes-for-host--default
  "根据 Git 主机和仓库名返回提交类别列表的函数。
函数接受 HOST、REPO-NAME 两个字符串参数，返回 alist。
可在 eon-secrets.el 中重新绑定，例如：
\(setq eon-commit-classes-for-host #'my-commit-classes-for-host)"
  :group 'eon
  :type 'function)


(defun eon--prompt-for-commit-class (commit-class)
  (let* ((repo-info (eon-git-util-repo-info))
	 (host (funcall repo-info 'host))
	 (repo-name (funcall repo-info 'name))
	 (inhibit-quit t)
	 (result nil))
    (unless (with-local-quit
	      (ivy-read "选择提交类别："
			(funcall eon-commit-classes-for-host host repo-name)
			:caller 'eon--prompt-for-commit-class
			:action #'(lambda (item) (setq result (cdr item)))))
      (progn
	(message "未选择提交类型")
	(setq quit-flag nil)))
    result))


(defun eon-insert-commit-class (commit-class)
  "自动插入提交的标信息，标识提交的类别。"
  (interactive
   (list (eon--prompt-for-commit-class eon-git-commit-class)))
  (when commit-class
    (goto-char (point-min))
    (insert commit-class)
    (save-buffer)))


(defun eon-insert-commit-class-wrapper ()
  (call-interactively 'eon-insert-commit-class))


(defun eon--ensure-git-user-identity-on-commit-setup ()
  "在提交缓冲区打开后检查用户身份，避免干扰后续提交类别选择。"
  (unless (eon--ensure-git-user-identity)
    (when (fboundp 'with-editor-cancel)
      (with-editor-cancel))))


(defun eon--ensure-git-user-identity-before-direct-commit ()
  (unless (eon--ensure-git-user-identity)
    (user-error "未设置 Git 用户信息，已取消提交")))


(use-package magit
  :ensure t
  :config
  (define-advice magit-run-git (:before (&rest args) eon--ensure-git-user-identity-direct)
    (when (equal (car args) "commit")
      (eon--ensure-git-user-identity-before-direct-commit)))
  (setq magit-log-margin
	'(t "%Y-%m-%d %H:%M " magit-log-margin-width t 18))
  (define-key magit-status-mode-map (kbd "C-w") nil)
  (define-key magit-diff-mode-map (kbd "C-w") nil)
  (define-key magit-log-mode-map (kbd "C-w") nil)
  (define-key magit-process-mode-map (kbd "C-w") nil)

  ;; 设置仓库列表的显示列
  (setq magit-repolist-columns
	'(("仓库名" 40 magit-repolist-column-ident nil)
	  ("分支" 35 magit-repolist-column-branch
	   ((:sort magit-repolist-version<)))
	  ("分支数" 8 magit-repolist-column-branches nil)
	  ("提交摘要" 8 eon-magit-uncommitted-changes-count nil)
	  ("路径" 99 magit-repolist-column-path nil)))
  :init
  (add-hook 'git-commit-setup-hook 'eon--ensure-git-user-identity-on-commit-setup 50))

(use-package magit-lfs
  :ensure t
  :after (magit))

(use-package blamer
  :bind (("s-i" . blamer-show-commit-info)
         ("C-c i" . blamer-show-posframe-commit-info))
  :custom
  (blamer-idle-time 0.1)
  (blamer-min-offset 20)
  :custom-face
  (blamer-face ((t :foreground "#7a88cf"
                   :background nil
                   :height 140
                   :italic t))))

;;;###autoload
(defun eon-magit-uncommitted-changes-count (spec)
  "显示当前仓库是否还有未提交的变更"
  (interactive)
  (let* ((output (shell-command-to-string "git status --porcelain"))
	 (uncommitted (if (string-empty-p output)
			  0
			(let ((lines (split-string output "\n" t)))
			  (length lines))))
	 (unpushed (and-let* ((br (magit-get-push-branch nil t)))
		     (car (magit-rev-diff-count "HEAD" br))))
	 (unpulled (and-let* ((br (magit-get-upstream-branch)))
		     (cadr (magit-rev-diff-count "HEAD" br)))))
    (format "%d/%d/%d" uncommitted (or unpushed 0) (or unpulled 0))))

;;;###autoload
(transient-define-prefix eon-magit-commit ()
  "魔改版 magit-commit"
  :info-manual "(magit)Initiating a Commit"
  :man-page "git-commit"
  ["Arguments"
   ("-a" "Stage all modified and deleted files"   ("-a" "--all"))
   ("-e" "Allow empty commit"                     "--allow-empty")
   ("-v" "Show diff of changes to be committed"   ("-v" "--verbose"))
   ("-n" "Disable hooks"                          ("-n" "--no-verify"))
   ("-R" "Claim authorship and reset author date" "--reset-author")
   (magit:--author :description "Override the author")
   (7 "-D" "Override the author date" "--date=" transient-read-date)
   ("-s" "Add Signed-off-by line"                 ("-s" "--signoff"))
   (5 magit:--gpg-sign)
   (magit-commit:--reuse-message)]
  [["Create"
    ("c" "Commit"         magit-commit-create)]
   ["Edit HEAD"
    ("e" "Extend"         magit-commit-extend)
    ("w" "Reword"         magit-commit-reword)
    ("a" "Amend"          magit-commit-amend)
    (6 "n" "Reshelve"     magit-commit-reshelve)]
   ["Edit"
    ("f" "Fixup"          magit-commit-fixup)
    ("s" "Squash"         magit-commit-squash)
    ("A" "Augment"        magit-commit-augment)
    (6 "x" "Absorb changes" magit-commit-autofixup)
    (6 "X" "Absorb modules" magit-commit-absorb-modules)]
   [""
    ("F" "Instant fixup"  magit-commit-instant-fixup)
    ("S" "Instant squash" magit-commit-instant-squash)
    ("g" "Goto repo" eon-open-current-git-repo)
    ("p" "Workspace" eon-workspace-magit-command)]]
  (interactive)
  (if-let ((buffer (magit-commit-message-buffer)))
      (switch-to-buffer buffer)
    (transient-setup 'eon-magit-commit)))

(fset 'magit-commit 'eon-magit-commit)


;;;###autoload
(defun eon-magit-branch-checkout (branch &optional start-point)
  "对magit-branch-checkout进行修改，只列出本地分支"
  (declare (interactive-only magit-call-git))
  (interactive
   (let* ((current (magit-get-current-branch))
          (local   (magit-list-local-branch-names))
          (remote  nil)
          (choices (nconc (delete current local) nil))
          (atpoint (magit-branch-at-point))
          (choice  (magit-completing-read
                    "Checkout branch" choices
                    nil nil nil 'magit-revision-history
                    (or (car (member atpoint choices))
                        (and atpoint
                             (car (member (and (string-match "[^/]+/" atpoint)
                                               (substring atpoint (match-end 0)))
                                          choices)))))))
     (cond ((member choice remote)
            (list (and (string-match "[^/]+/" choice)
                       (substring choice (match-end 0)))
                  choice))
           ((member choice local)
            (list choice))
           (t
            (list choice (magit-read-starting-point "Create" choice))))))
  (cond
   ((not start-point)
    (magit--checkout branch (magit-branch-arguments))
    (magit-refresh))
   (t
    (when (magit-anything-modified-p t)
      (user-error "Cannot checkout when there are uncommitted changes"))
    (magit-run-git-async "checkout" (magit-branch-arguments)
                         "-b" branch start-point)
    (set-process-sentinel
     magit-this-process
     (lambda (process event)
       (when (memq (process-status process) '(exit signal))
         (magit-branch-maybe-adjust-upstream branch start-point)
         (when (magit-remote-branch-p start-point)
           (pcase-let ((`(,remote . ,remote-branch)
                        (magit-split-branch-name start-point)))
             (when (and (equal branch remote-branch)
                        (not (equal remote (magit-get "remote.pushDefault"))))
               (magit-set remote "branch" branch "pushRemote"))))
         (magit-process-sentinel process event)))))))

;;;###autoload (autoload 'magit-branch "magit" nil t)
(transient-define-prefix eon-magit-branch (branch)
  "魔改版 magit-branch"
  :man-page "git-branch"
  [:if (lambda () (and magit-branch-direct-configure (transient-scope)))
   :description
   (lambda ()
     (concat (propertize "Configure " 'face 'transient-heading)
             (propertize (transient-scope) 'face 'magit-branch-local)))
   ("d" magit-branch.<branch>.description)
   ("u" magit-branch.<branch>.merge/remote)
   ("r" magit-branch.<branch>.rebase)
   ("p" magit-branch.<branch>.pushRemote)]
  [:if-non-nil magit-branch-direct-configure
   :description "Configure repository defaults"
   ("R" magit-pull.rebase)
   ("P" magit-remote.pushDefault)
   ("B" "Update default branch" magit-update-default-branch
    :inapt-if-not magit-get-some-remote)]
  ["Arguments"
   (7 "-r" "Recurse submodules when checking out an existing branch"
      "--recurse-submodules")]
  [["Checkout"
    ("b" "branch/revision"   magit-checkout)
    ("l" "local branch"      eon-magit-branch-checkout)
    ("L" "local branch"      magit-branch-checkout)
    (6 "o" "new orphan"      magit-branch-orphan)]
   [""
    ("c" "new branch"        magit-branch-and-checkout)
    ("s" "new spin-off"      magit-branch-spinoff)
    (5 "w" "new worktree"    magit-worktree-checkout)]
   ["Create"
    ("n" "new branch"        magit-branch-create)
    ("S" "new spin-out"      magit-branch-spinout)
    (5 "W" "new worktree"    magit-worktree-branch)]
   ["Do"
    ("C" "configure..."      magit-branch-configure)
    ("m" "rename"            magit-branch-rename)
    ("x" "reset"             magit-branch-reset)
    ("k" "delete"            magit-branch-delete)]
   [""
    (7 "h" "shelve"          magit-branch-shelve)
    (7 "H" "unshelve"        magit-branch-unshelve)]]
  (interactive (list (magit-get-current-branch)))
  (transient-setup 'eon-magit-branch nil nil :scope branch))

(fset 'magit-branch 'eon-magit-branch)

;;;###autoload
(defun eon-magit-branch-read-args (prompt &optional default-start)
  "创建新分支时，规范分支命名"
  (if magit-branch-read-upstream-first
      (let ((choice (magit-read-starting-point prompt nil default-start)))
        (cond
         ((magit-rev-verify choice)
          (let* ((branch-type (ivy-read "选择分支类型: " '("feat" "fix" "chore" "raw")))
                 (date-string (format-time-string "%Y%m%d"))
                 (branch-name (magit-read-string-ns
                               (if magit-completing-read--silent-default
                                   (format "%s (starting at `%s')" prompt choice)
                                 "Name for new branch")
                               (let ((def (mapconcat #'identity
                                                     (cdr (split-string choice "/"))
                                                     "/")))
                                 (and (member choice (magit-list-remote-branch-names))
                                      (not (member def (magit-list-local-branch-names)))
                                      def))))
                 (full-branch-name (if (string= branch-type "raw")
				       branch-name
				     (format "%s/%s/%s" branch-type date-string branch-name))))
            (list full-branch-name choice)))
         ((eq magit-branch-read-upstream-first 'fallback)
          (list choice
                (magit-read-starting-point prompt choice default-start)))
         ((user-error "Not a valid starting-point: %s" choice))))
    (let* ((branch-type (ivy-read "选择分支类型: " '("feat" "fix" "chore")))
           (date-string (format-time-string "%Y%m%d"))
           (branch (magit-read-string-ns (concat prompt " named")))
           (full-branch-name (format "%s/%s/%s" branch-type date-string branch)))
      (if (magit-branch-p full-branch-name)
          (eon-magit-branch-read-args
           (format "Branch `%s' already exists; pick another name" full-branch-name)
           default-start)
        (list full-branch-name (magit-read-starting-point prompt full-branch-name default-start))))))

(fset 'magit-branch-read-args 'eon-magit-branch-read-args)

;;;###autoload
(defun eon-open-current-git-repo (&optional commit args)
  (interactive)
  (when magit--default-directory
    (eon-open-git-repo magit--default-directory)))

;;;###autoload
(defun eon-workspace-magit-command (&optional commit args)
  (interactive)
  (let ((break nil)
	(command-key nil))
    (while (not break)
      (let ((key (read-key "")))
	(let ((command (pcase (string key)
			 ("s" #'eon-workspace-create)
			 ("g" #'eon-workspace-rg)
			 ("f" #'eon-workspace-find-file)
			 (_ nil))))
	  (setq break t)
	  (if command
	      (progn
		(call-interactively command)
		(setq this-command command))
	    (message "无效的指令 %s" (string key))))))))

(defun eon-open-git-repo (repo-path)
  "获取并显示指定Git仓库的远程URL，如果是SSH格式则转换为HTTP格式"
  (interactive)
  (let ((default-directory repo-path))
    (let* ((info (eon-git-util-repo-info))
	   (url (format "https://%s/%s" (funcall info 'host) (funcall info 'name))))
      (browse-url url))))

(defun eon-magit-repolist-fetch-at-point ()
  "Fetch the repository at point."
  (interactive)
  (when-let ((repo (tabulated-list-get-id)))
    (run-hooks 'magit-credential-hook)
    (let ((default-directory (file-name-as-directory (expand-file-name repo))))
      (magit-run-git "remote" "update"))))

(defun eon-magit-repolist-open-git-http ()
  "打开当前仓库"
  (interactive)
  (when (derived-mode-p 'magit-repolist-mode)
    (if-let* ((entry (tabulated-list-get-id)))
	(eon-open-git-repo entry))))

(defun eon-magit-diff-branches ()
  "对比两个本地分支，忽略空白变更"
  (interactive)
  (let* ((branches (magit-list-local-branch-names))
         (default-branch (or (car (member "master" branches))
                             (car (member "main" branches))))
         (branch1 (magit-completing-read "选择第一个分支: " branches nil nil nil nil default-branch))
         (branch2 (magit-completing-read "选择第二个分支: " branches)))
    (magit-diff-range (format "%s..%s" branch1 branch2) '("--ignore-space-change" "--no-ext-diff" "--stat"))))

;;;###autoload
(defun eon-magit-create-dev-tag ()
  "创建开发类型的tag"
  (interactive)
  (let* ((branch (magit-get-current-branch))
	 (tag-prefix (concat branch "-"))
         (tag-suffix "-dev")
         ;; 先同步远端tag
         (magit-git-global-arguments (cons "--no-pager" magit-git-global-arguments))
         (_ (magit-run-git "fetch" "--tags" "--force"))
         (all-tags (magit-list-tags))
         (pattern (concat "^" (regexp-quote tag-prefix) ".*" (regexp-quote tag-suffix) "$"))
         (existing-tags (seq-filter (lambda (tag)
                                      (string-match-p pattern tag))
                                    all-tags))
         (latest-version "1.0.0"))

    ;; 查找最新的版本号
    (when existing-tags
      (let* ((latest-tag (car (last (sort existing-tags 'string<))))
             (version (string-remove-prefix tag-prefix (string-remove-suffix tag-suffix latest-tag)))
             (version-parts (mapcar 'string-to-number (split-string version "\\."))))
        (setq latest-version
              (format "%d.%d.%d"
                      (car version-parts)
                      (cadr version-parts)
                      (1+ (caddr version-parts))))))

    (let ((tag-name (concat tag-prefix latest-version tag-suffix)))
      (magit-run-git "tag" tag-name)
      (message "创建TAG: %s" tag-name))))

(defun eon-magit-repo-tag-info--read-repo (default)
  "选择git仓库目录，默认使用 DEFAULT。"
  (require 'eon-workspace)
  (let* ((projects (eon-workspace--known-projects))
         (pairs (when projects (eon-workspace--project-display-pairs projects)))
         (choices (mapcar #'car pairs)))
    (if (not choices)
        (read-directory-name "选择仓库: " default nil t)
      (let* ((default-pair (cl-find default pairs :test #'string= :key #'cdr))
             (default-display (if default-pair (car default-pair) (car choices)))
             (selected (completing-read "选择工作区: " choices nil t nil nil default-display)))
        (cdr (assoc-string selected pairs))))))

(defun eon-magit-repo-tag-info--repo-urls (default-directory)
  "Return (commit-url-base . author-url-base) for the repo at DEFAULT-DIRECTORY."
  (let* ((info (ignore-errors (eon-git-util-repo-info)))
         (host (and info (funcall info 'host)))
         (name (and info (string-remove-suffix ".git" (funcall info 'name)))))
    (when (and host name)
      (cons (format "https://%s/%s/commit/" host name)
            (format "https://%s/" host)))))

(defun eon-magit-repo-tag-info ()
  "对比两个tag之间的提交变更信息"
  (interactive)
  (let* ((current-repo (or (ignore-errors (magit-toplevel)) default-directory))
         (repo (eon-magit-repo-tag-info--read-repo current-repo))
         (default-directory repo))
    (magit-run-git "fetch" "--tags" "--force")
    (let* ((tags (magit-list-tags))
           (sorted-tags (sort tags #'string<)))
      (unless sorted-tags
        (user-error "该仓库没有tag"))
      (let* ((old-tag (completing-read "旧tag: " sorted-tags nil t))
             (rest (cdr (member old-tag sorted-tags)))
             (new-tag (completing-read "新tag: " rest nil t))
             (range (format "%s..%s" old-tag new-tag))
             (urls (eon-magit-repo-tag-info--repo-urls repo))
             (log-output (shell-command-to-string
                          (format "git log --format=\"%%h%%x09%%s%%x09%%an\" %s" range)))
             (buf (get-buffer-create "*eon-tag-diff*")))
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "# 提交变更: `%s`\n\n" range))
            (if (string-empty-p (string-trim log-output))
                (insert "*无提交记录*\n")
              (dolist (line (split-string log-output "\n" t))
                (let ((parts (split-string line "\t")))
                  (when (>= (length parts) 3)
                    (cl-destructuring-bind (hash subject author) parts
                      (if urls
                          (insert (format "- [`%s`](%s%s) %s — [%s](%s%s)\n"
                                          hash (car urls) hash
                                          subject
                                          author (cdr urls) author))
                        (insert (format "- `%s` %s — %s\n"
                                        hash subject author))))))))
            (goto-char (point-min))
            (markdown-mode)))
        (pop-to-buffer buf)))))
(provide 'eon-vcs)
