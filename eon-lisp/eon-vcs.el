;;; -*- lexical-binding: t -*-

;;; 版本控制系统

(require 'eon-git-util)

;; 屏蔽 with-editor fails to find a suitable emacsclient 错误
(setq-default with-editor-emacsclient-executable "emacsclient")

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

(defcustom eon-git-commit-class-woa
  '(("feat -- 新特性" . "feat: ")
    ("fix -- 修复软件问题" . "fix: ")
    ("chore -- 杂项" . "chore: ")
    ("refactor -- 重构" . "refactor: ")
    ("style -- 样式重构" . "style: ")
    ("perf -- 性能优化" . "perf: ")
    ("ci -- 持续集成" . "ci: ")
    ("build -- 构建" . "build: ")
    ("test -- 测试" . "test: ")
    ("debug -- 调试" . "debug: ")
    ("jty -- 临时提交" . "[临时]: "))
  "Git提交类别定义"
  :group 'eon
  :type '(alist :key-type string :value-type string))

(defcustom eon-git-commit-class
  '(("sgn -- 配置" . "[配置]: ")
    ("ipb -- 学习" . "[学习]: 提交")
    ("ful -- 增减软件功能" . "[新功能]: ")
    ("wht -- 修复软件问题" . "[修复]: ")
    ("vs -- 杂项" . "[杂项]: ")
    ("jty -- 临时提交" . "[临时]: ")
    ("sud -- 样式修改" . "[样式修改]: ")
    ("ntg -- 性能优化" . "[性能优化]: ")
    ("rff -- 持续集成" . "[持续集成]: ")
    ("sqc -- 构建" . "[构建]: ")
    ("imj -- 测试" . "[测试]: ")
    ("tgj -- 重构现有逻辑，无功能变动" . "[重构]: "))
  "Git提交类别定义"
  :group 'eon
  :type '(alist :key-type string :value-type string))

(defun eon--prompt-for-commit-class (commit-class)
  (let* ((repo-info (eon-git-util-repo-info))
	 (host (funcall repo-info 'host))
	 (inhibit-quit t)
	 (result nil))
    (unless (with-local-quit
	      (ivy-read "选择提交类别：" (pcase host
					   ("git.woa.com" eon-git-commit-class-woa)
					   (_ eon-git-commit-class))
			:caller 'eon--prompt-for-commit-class
			:action #'(lambda (item) (setq result (cdr item)))))
      (progn
	(message "未选择提交类型")
	(setq quit-flag nil)))
    result))


(defun eon--build-commit-auto-msg (commit-class)
  "根据多种情况，构造自动提交信息"
  (if (not (string-equal commit-class "[临时]: "))
      commit-class
    (let ((branch (magit-get-current-branch)))
      (if (or (string-equal branch "master")
	      (string-equal branch "main"))
	  commit-class
	(let ((last-msg (magit-rev-format "%s" branch)))
	  (if (string-match "^\\[临时\\]:[ ]f\\([0-9]+\\)$" last-msg)
	      (let ((number (string-to-number (match-string 1 last-msg))))
		(format "[临时]: f%d" (+ number 1)))
	    "[临时]: "))))))


(defun eon-insert-commit-class (commit-class)
  "自动插入提交的标信息，标识提交的类别。"
  (interactive
   (list (eon--prompt-for-commit-class eon-git-commit-class)))
  (if commit-class
      (progn
	(goto-char (point-min))
	(let ((commit-msg (eon--build-commit-auto-msg commit-class)))
	  (insert commit-msg)
	  (save-buffer)))))


(defun eon-insert-commit-class-wrapper ()
  (call-interactively 'eon-insert-commit-class))

(use-package magit
  :ensure t
  :config
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
  (add-hook 'git-commit-setup-hook 'eon-insert-commit-class-wrapper 100))

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
(defun eon-magit-commit-create-tmp ()
  (interactive)
  (let ((commit-msg (eon--build-commit-auto-msg "[临时]: ")))
    (if (string-equal commit-msg "[临时]: ")
	(magit-commit-create)
      (magit-run-git "commit" "-m" (format "%s" commit-msg)))))

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
    ("c" "Commit"         magit-commit-create)
    ("t" "CommitTmp"      eon-magit-commit-create-tmp)]
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
    ("p" "Projectile" eon-magit-projectile-command)]]
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
(defun eon-magit-projectile-command (&optional commit args)
  (interactive)
  (let ((break nil)
	(command-key nil))
    (while (not break)
      (let ((key (read-key "")))
	(let ((command (pcase (string key)
			 ("s" #'projectile-switch-project)
			 ("g" #'counsel-projectile-grep)
			 ("f" #'counsel-projectile-find-file)
			 ("o" #'eon-work-module-open)
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

(provide 'eon-vcs)
