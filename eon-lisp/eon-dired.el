;;; -*- lexical-binding: t -*-

(defun eon--not-dot-dot-file (name)
  "从文件列表中过滤掉 . 和 .."
  (if (file-name-absolute-p name)
      (not (or (string-equal (file-name-nondirectory name) ".")
	       (string-equal (file-name-nondirectory name) "..")))
    (not (or (string-equal name ".")
	     (string-equal name "..")))))

(defun eon-copy-dired-files-list (with-dir)
  "复制文件列表"
  (interactive
   (list (y-or-n-p "是否包含目录？")))
  (let ((files (dired-get-marked-files (if with-dir nil "no-dir"))))
    (kill-new (mapconcat 'identity files "\n"))
    (message "Copied %d files to kill ring" (length files))))

(defun eon-find-marked-files ()
  "后台打开所有已标记文件"
  (interactive)
  (let ((file-list
	 (dired-get-marked-files nil nil 'eon--not-dot-dot-file)))
    (while file-list
      (find-file-noselect (car file-list))
      (pop file-list))))

(defun eon-smart-dired-copy-fun ()
  "如果有文本选区，执行正常的复制功能，否则执行文件复制"
  (interactive)
  (if (use-region-p)
      (call-interactively 'kill-ring-save)
    (call-interactively 'dired-ranger-copy)))

(use-package dired-hacks
  :after (dired)
  :bind (:map dired-mode-map
	      ("C-y" . dired-ranger-paste)
	      ("M-w" . eon-smart-dired-copy-fun)
	      ))

(use-package dired-narrow
  :ensure nil
  :after (dired)
  :bind (:map dired-mode-map
	      ("C-s" . dired-narrow-regexp)
	      ("M-p" . dired-up-directory))
  :hook (dired-mode . dired-narrow-mode))


(use-package all-the-icons-dired
  :defer t
  :diminish
  :config (setq all-the-icons-dired-monochrome nil)
  :hook
  (dired-mode . all-the-icons-dired-mode))


(use-package dired-x
  :ensure nil
  :config
  (setq dired-omit-size-limit nil))

(defvar eon-dired-omit-extensions-dir
  '("~/work")
  "用于保存要忽略的特定扩展的目录")

(define-advice dired-omit-expunge (:around (origin-fun &optional regexp linep init-count) eon-dired-omit)
  (if (stringp dired-directory)
      (if (eon-path-list-contains eon-dired-omit-extensions-dir dired-directory)
	  (apply origin-fun regexp linep init-count)
	(let (dired-omit-extensions)
	  (apply origin-fun regexp linep init-count)))
    (message "Dired目录不是字符串 %s" dired-directory)))

(use-package dired
  :ensure nil
  :bind
  (:map dired-mode-map ("F" . eon-find-marked-files)))


(provide 'eon-dired)
