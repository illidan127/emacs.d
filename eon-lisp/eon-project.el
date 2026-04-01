;;; -*- lexical-binding: t -*-

;;; 工程配置相关

(defun eon-projectile-add-directories-recursively (&rest dirs)
  "将DIRS目录及其子目录添加到`projectile-known-projects'中。
每个DIRS参数应为字符串形式的路径。"
  (interactive "D递归添加目录: \n")
  (dolist (dir dirs)
    (when (file-directory-p dir)
      (dolist (subdir (directory-files dir t "^[^.].*" t))
        (when (and (file-directory-p subdir)
                   (not (string-match-p "/\\.\\.?$" subdir)))
          (add-to-list 'projectile-known-projects
		       (file-name-as-directory (abbreviate-file-name subdir)))))))
  (message "已添加 %d 个目录到已知工程列表" (length dirs)))

(use-package projectile
  :init
  (put 'projectile-project-root 'safe-local-variable #'stringp)
  (setq projectile-command-map (make-sparse-keymap))
  :bind
  (:map
   projectile-command-map
   ("f" . #'counsel-projectile-find-file)
   ("s" . #'projectile-switch-project)
   ("g" . #'counsel-projectile-rg))
  :config
  (setq projectile-auto-discover nil) ;; 不自动添加工程
  (setq projectile-track-known-projects-automatically nil)
  (setq projectile-enable-caching nil)
  (setq projectile-mode-line-prefix " 工程")
  (setq projectile-indexing-method 'alien)
  (setq projectile-sort-order 'default)
  ;; 使用fd替换git ls-files
  (setq projectile-git-use-fd t)
  ;; 使用.projectile来做忽略列表
  (setq projectile-git-fd-args "-H -0 -E .git -tf --strip-cwd-prefix -c never --ignore-file=.projectile")
  ;; 使用自定义的fd封装，防止出现.projectile找不到错误
  (setq projectile-fd-executable "fdw")
  (setq projectile-require-project-root 'prompt)

  (defun eon-projectile-switch-project-action ()
    "因切换项目而调用projectile-find-file时，清除
文件缓存，解决文件列表错误问题"
    (projectile-find-file t))
  (setq projectile-switch-project-action
	'eon-projectile-switch-project-action)
  (define-key
   projectile-mode-map
   (kbd "C-c p")
   'projectile-command-map))

(defun eon-project-add-subdirs-to-projects ()
  "Add all immediate subdirectories of current directory to projectile known projects."
  (interactive)
  (let ((dir default-directory))
    (dolist (subdir (directory-files dir t "^[^.].*" t))
      (when (and (file-directory-p subdir)
                 (not (string-match-p "/\\.\\.?$" subdir)))
        (projectile-add-known-project (file-name-as-directory (abbreviate-file-name subdir)))))))

(defun eon-reset-magit-repository-list ()
  "切换项目后，重置 `magit-repository-directories'"
  (interactive)
  (let* ((repo-dir (vc-root-dir))
         (cur-dir (when repo-dir (file-name-directory (directory-file-name repo-dir))))
         (work-dir (expand-file-name "work/" (getenv "HOME"))))
    (when (and cur-dir
               (file-in-directory-p cur-dir work-dir))
      (if (not (string-equal (expand-file-name cur-dir) work-dir))
	  (let ((repos (seq-filter
			(lambda (dir)
			  (file-exists-p (expand-file-name ".git" dir)))
			(directory-files cur-dir t "^[^.].*" t))))
            (setq magit-repository-directories
		  (mapcar (lambda (dir) (cons dir 0)) repos)))
	(setq magit-repository-directories nil)))))


(defun eon-magit-status-wrapper ()
  "根据情况执行`magit-status'或`magit-repolist-status'"
  (interactive)
  (eon-reset-magit-repository-list)
  (if magit-repository-directories
      (call-interactively #'magit-list-repositories)
    (call-interactively #'magit-status)))


(use-package
  counsel-projectile
  :defer t
  :after (projectile)
  :init
  (setq counsel-projectile-key-bindings '())
  (counsel-projectile-mode))


(use-package perspective
  :config
  (defun persp-get-scratch-buffer (&optional name)
    "覆盖原有的 `persp-get-scratch-buffer'"
    (find-file initial-buffer-choice))
  :custom
  (persp-mode-prefix-key (kbd "C-c C-e"))
  :bind
  (("<f8>" . persp-switch))
  (("s-`" . persp-next))
  :hook
  (emacs-startup . (lambda () (persp-state-load persp-state-default-file)))
  (kill-emacs . persp-state-save)
  (persp-switch . (lambda () (set-frame-name (persp-current-name)) (persp-state-save)))
  (persp-after-rename . persp-state-save)
  (persp-created . persp-state-save)
  :init
  (setq persp-state-default-file  (f-join persp-save-dir "perspective-session"))
  (persp-mode))

(provide 'eon-project)
