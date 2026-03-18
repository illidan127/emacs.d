;;; -*- lexical-binding: t -*-

;; 编辑相关配置

(use-package multiple-cursors)

(use-package visual-regexp
  :bind ("C-c r" . vr/replace))

(use-package visual-regexp-steroids
  :requires (visual-regexp))

(use-package swiper
  :commands (swiper swiper-thing-at-point swiper-backward)
  :bind
  (:map
   global-map
   ("C-s" . swiper)
   ("C-*" . swiper-thing-at-point)
   ("C-r" . swiper-backward)))

(use-package ivy
  :ensure nil
  :diminish
  :init (add-hook 'after-init-hook 'ivy-mode))

(use-package smex)

(use-package counsel
  :ensure nil
  :bind
  (:map global-map
	("C-h f" . counsel-describe-function)
	("C-h v" . counsel-describe-variable)
	("M-x" . counsel-M-x)))

(use-package posframe)

(use-package company-posframe
  :requires posframe
  :diminish company-posframe-mode)

(use-package yasnippet
  :diminish
  :requires (no-littering)
  :config (yas-reload-all))

(use-package company
  :diminish " 补"
  :config
  (setq
   company-idle-delay 0
   company-show-quick-access t		; M-[0-9]快速选择
   company-transformers '(company-sort-by-occurrence) ;根据选择频率排序
   company-selection-wrap-around t)
  (company-posframe-mode 1)
  :bind
  (:map company-active-map
	("<tab>" . (lambda () (interactive)
		     (if (and company-candidates-length
			      (= company-candidates-length 1))
			 (call-interactively 'company-complete-selection)
		       (call-interactively 'company-select-next))))
	("<backtab>" . company-select-previous)))

(use-package company-box
  :diminish
  :requires (company)
  :if window-system
  :hook (company-mode . company-box-mode))

(use-package highlight-symbol
  :diminish
  :hook (prog-mode . highlight-symbol-mode)
  :bind
  (:map prog-mode-map
	("M-m" . highlight-symbol)
	("M-n" . highlight-symbol-next)
	("M-p" . highlight-symbol-prev)))

(use-package mwim
  :bind
  ("C-a" . mwim-beginning)
  ("C-e" . mwim-end))

(use-package marginalia
  :init (marginalia-mode))

(use-package comment-tags
  :config
  (setq comment-tags-keyword-faces
	`(("TODO" . ,(list :weight 'bold :foreground "#28ABE3"))
	  ("FIXME" . ,(list :weight 'bold :foreground "#DB3340"))
	  ("BUG" . ,(list :weight 'bold :foreground "#DB3340"))
	  ("HACK" . ,(list :weight 'bold :foreground "#E8B71A"))
	  ("KLUDGE" . ,(list :weight 'bold :foreground "#E8B71A"))
	  ("XXX" . ,(list :weight 'bold :foreground "#F7EAC8"))
	  ("INFO" . ,(list :weight 'bold :foreground "#F7EAC8"))
	  ("DONE" . ,(list :weight 'bold :foreground "#1FDA9A"))))
  (setq comment-tags-comment-start-only nil
	comment-tags-require-colon nil
	comment-tags-case-sensitive t
	comment-tags-show-faces t
	comment-tags-lighter nil)
  :hook
  (prog-mode . comment-tags-mode)
  (org-mode . comment-tags-mode))


(defun eon-reencode-line (start end)
  "某些编辑器不管文本文件的本来编码，直接写入其他编码字符，导致文件部分乱码。
常见于 utf-8 文本中增加部分 gbk，gb18030 编码文本。对此 emacs 很可能识别成 windows-1254 编码，
解决方法为文件整体强制使用 utf-8，并对其中乱码部分重新用 gb18030 解码"
  (interactive "r")
  (recode-region start end 'gb18030 'utf-8))

(use-package temporary-persistent
  :config
  (let ((temp-dir (file-name-as-directory (expand-file-name "~/temp/"))))
    (add-to-list 'auto-mode-alist
                 (cons (concat "\\`" (regexp-quote temp-dir) "temp\\'")
                       'text-mode))
    (add-to-list 'auto-mode-alist
                 (cons (concat "\\`" (regexp-quote temp-dir) "temp.*\\'")
                       'text-mode)))
  :bind ("<f1>" . temporary-persistent-switch-buffer))

(use-package editorconfig
  :config (editorconfig-mode 1))

;; (use-package multi-vterm :after (vterm))

(defun eon-dos2unix (buffer)
  "将当前文件格式从 dos 转为 unix"
  (interactive "*b")
  (save-excursion
    (goto-char (point-min))
    (while (search-forward (string ?\C-m) nil t)
      (replace-match (string ?\C-j) nil t))))


;; 移动文本
(use-package move-text
  :config
  (move-text-default-bindings))

(use-package edit-server
  :commands edit-server-start
  :init (if after-init-time
            (edit-server-start)
          (add-hook 'after-init-hook
                    #'(lambda() (edit-server-start))))
  :config (setq edit-server-new-frame-alist
                '((name . "Edit with Emacs FRAME")
                  (top . 200)
                  (left . 200)
                  (width . 80)
                  (height . 25))))


(use-package which-key)

(defun eon--current-position-info ()
  (let ((file (buffer-file-name))
	(line (line-number-at-pos))
	(column (current-column)))
    (format "%s - %s - %s" file line column)))

(defun eon-get-current-position-fino ()
  "获取当前光标的位置信息"
  (interactive)
  (kill-new (eon--current-position-info)))


(use-package dash)

(use-package image-slicing
  :disabled
  :after (eon-org)
  :hook
  (org-mode . org-toggle-inline-images)
  (org-mode . image-slicing-mode))

(use-package sokoban
  :requires (no-littering)
  :config
  (setq sokoban-state-filename "~/.emacs.d/data/sokoban-state"))

(use-package youdao-dictionary
  :requires (posframe)
  :if (and (boundp 'youdao-dictionary-app-key)
           (stringp youdao-dictionary-app-key)
           (> (length youdao-dictionary-app-key) 0)
           (boundp 'youdao-dictionary-secret-key)
           (stringp youdao-dictionary-secret-key)
           (> (length youdao-dictionary-secret-key) 0))
  :init
  ;; 需要设置以下两个变量
  ;; (setq youdao-dictionary-app-key "...")
  ;; (setq youdao-dictionary-secret-key "...")
  :bind
  ("C-c d" . youdao-dictionary-search-at-point-posframe))

(provide 'eon-editor)
