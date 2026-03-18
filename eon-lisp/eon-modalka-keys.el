;; -*- lexical-binding: t; -*-

(require 'cl)

;;; modalka 按键适配

;;; 特殊模式处理

(defvar eon-sub-keymap-waiting-time 1.0
  "进入子按键后等待时间")

(defun eon-magit-key-lookup (key)
  (magit-section-case
    (unstaged (keymap-lookup (list magit-file-section-map magit-status-mode-map) key nil nil))
    (file (keymap-lookup (list magit-file-section-map magit-status-mode-map) key nil nil))
    (hunk (keymap-lookup (list magit-hunk-section-map magit-status-mode-map) key nil nil))
    (t (keymap-lookup magit-status-mode-map key nil nil))))

(defun eon-magit-key-infer (key)
  (interactive)
  (eon-magit-key-lookup key))

;;; 按键适配

(defun em-b ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "b"))
	   (_ "C-b"))))
    realkey))

(defun em-c-command ()
  (interactive)
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "p s") #'projectile-switch-project)
    (define-key keymap (kbd "p g") #'counsel-projectile-rg)
    (define-key keymap (kbd "p f") #'counsel-projectile-find-file)
    (define-key keymap (kbd "p o") #'eon-work-module-open)
    (define-key keymap (kbd "d") #'youdao-dictionary-search-at-point-posframe)
    (if (eq major-mode 'magit-log-select-mode)
	(progn
	  (define-key keymap (kbd "c") #'magit-log-select-pick)
	  (define-key keymap (kbd "k") #'magit-log-select-quit)))
    (if (derived-mode-p 'prog-mode)
	(define-key keymap (kbd "i") #'counsel-imenu))
    (if with-editor-mode
	(progn
	  (define-key keymap (kbd "c") #'with-editor-finish)
	  (define-key keymap (kbd "k") #'with-editor-cancel)))
    (if (and (boundp 'org-capture-mode) org-capture-mode)
	(progn
	  (define-key keymap (kbd "c") #'org-capture-finalize)
	  (define-key keymap (kbd "k") #'org-capture-kill)))
    (pcase major-mode
      (_ (set-transient-map keymap nil nil nil eon-sub-keymap-waiting-time)))))

;; em-<key> 处理逻辑
;; <key> 后单按键在第一层函数中处理，例如 magit-status-mode 中按键
;; 多按键在 eon-modal-<key>-command 中处理
;; 此时可以使用类似 k 键中 read-key 方法来逐键处理，也可以采用临时 keymap 方式来处理
;; 临时 keymap 在构造时，也可以根据当前的 major/minor mode 来增减按键
(defun em-c (&optional key-list)
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "c"))
	   (_ #'em-c-command))))
    realkey))

(defun em-d ()
  (let ((realkey
	 (pcase major-mode
	   ('dired-mode #'dired-flag-file-deletion)
	   ('magit-status-mode (eon-magit-key-infer "d"))
	   (_ "C-d"))))
    realkey))

(defun em-e ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "e"))
	   ('magit-log-select-mode #'magit-log-select-pick)
	   (_ "C-e"))))
    realkey))

(defun em-f ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "f"))
	   ('magit-repolist-mode #'magit-repolist-fetch)
	   ('ivy-occur-grep-mode #'ivy-occur-press)
	   ('ivy-occur-mode #'ivy-occur-press)
	   (_ "C-f"))))
    realkey))

(defun em-g ()
  (let ((realkey
	 (pcase major-mode
	   ('help-mode #'revert-buffer)
	   ('dired-mode #'revert-buffer)
	   ('ivy-occur-grep-mode #'ivy-occur-revert-buffer)
	   ('treemacs-mode #'treemacs-refresh)
	   ('org-agenda-mode #'org-agenda-redo-all)
	   ('magit-status-mode #'magit-refresh)
	   ('magit-repolist-mode #'revert-buffer)
	   (_ "C-g"))))
    realkey))

(defun em-i ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "i"))
	   (_ #'em-disable))))
    realkey))

(defun em-j ()
  (let ((realkey
	 (pcase major-mode
	   (_ #'ignore))))
    realkey))

(defun em-kill-full-line (arg)
  "将 ARG 行放入 kill ring"
  (save-excursion
    (move-beginning-of-line 1)
    (kill-line arg)))

(defun em-kill-word (arg)
  "从光标位置的词起算，剪切 ARG 个词（word）"
  (save-excursion
    (beginning-of-thing 'word)
    (let ((beg (point))
	  end)
      (forward-word arg)
      (setq end (point))
      (kill-region beg end))))

(defun em-kill-to-end (&optional arg)
  "从光标位置剪切到行尾，但不将下一行提上来"
  (kill-line nil))

(defun em-kill-to-beg (&optional arg)
  "从光标位置剪切到行首"
  (kill-line 0))

(defun em-kill-save-line (arg mode)
  "将 ARG 行放入 kill ring"
  (defun save-action ()
    (let ((beg (point))
	  end)
      (move-end-of-line arg)
      (setq end (point))
      (message "将 %s 到 %s 保存到 kill-ring" beg end)
      (kill-ring-save beg end)))
  (pcase major-mode
    ('org-mode (lambda ()
		 (interactive)
		 (save-excursion
		   (mwim-end)
		   (mwim-beginning)
		   (save-action))))
    (_ (lambda ()
	 (interactive)
	 (save-excursion
	   (move-beginning-of-line 1)
	   (pcase mode
	     ('l (back-to-indentation))
	     (_ nil))
	   (save-action))))))

(defun em-kill-save-word (arg)
  "从光标位置的词起算，保存 ARG 个词（word）"
  (interactive "P")
  (save-excursion
    (let ((beg (beginning-of-thing 'word))
	  end)
      (forward-word arg)
      (setq end (point))
      (kill-ring-save beg end))))

(defun em-kill-save-to-end (&optional arg)
  "从光标位置保存到行尾"
  (interactive "P")
  (save-excursion
    (let ((beg (point))
	  (end (or (move-end-of-line 1) (point))))
      (kill-ring-save beg end))))

(defun em-kill-save-to-beg (&optional arg)
  "从光标位置保存到行首"
  (interactive "P")
  (save-excursion
    (let ((beg (point))
	  (end (move-beginning-of-line 1)))
      (kill-ring-save beg end))))

(defun em-kill-save-command (num-arg)
  "剪贴板保存命令
当有 REGION 存在时，按 s 将 REGION 保存
否则继续等待后续指令"
  (if (use-region-p)
      (call-interactively #'kill-ring-save)
    (let ((keymap (make-sparse-keymap)))
      (define-key keymap (kbd "l") (em-kill-save-line num-arg 'l))
      (define-key keymap (kbd "L") (em-kill-save-line num-arg 'L))
      (define-key keymap (kbd "w") #'em-kill-save-word)
      (define-key keymap (kbd "a") #'em-kill-save-to-beg)
      (define-key keymap (kbd "e") #'em-kill-save-to-end)
      (set-transient-map keymap nil nil nil eon-sub-keymap-waiting-time))))

(defvar em-k-keymap
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "d") #'eon-smart-kill) ;; d 表示 dwim
    (define-key keymap (kbd "l") #'em-kill-full-line)
    (define-key keymap (kbd "k") #'em-kill-full-line) ;; kk 与 kl 相同操作
    (define-key keymap (kbd "w") #'em-kill-word)
    (define-key keymap (kbd "e") #'em-kill-to-end)
    (define-key keymap (kbd "a") #'em-kill-to-beg)
    (define-key keymap (kbd "s") #'em-kill-save-command)
    keymap)
  "modalka 模式按下 k 键后的键位图")

(defun em-k-command ()
  (interactive)
  (let ((break nil)
	(middle-args "")
	(command-key nil))
    (while (not break)
      (let ((key (read-key "")))
	(if (cl-digit-char-p key)
	    (setq middle-args (concat middle-args (string key)))
	  (progn
	    (setq command-key (string key))
	    (setq break t)))))
    (message "%s%s%s" "k" middle-args command-key)
    (let ((binding (keymap-lookup em-k-keymap (kbd command-key)))
	  (arg (string-to-number middle-args)))
      ;; (message "%s" binding)
      (unless (memq binding '(nil undefined))
	(apply binding (list (if (= arg 0) 1 arg)))
	(setq this-command binding)))))

(defun em-k ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "k"))
	   (_ #'em-k-command))))
    realkey))

(defun em-l ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "l"))
	   (_ "C-l"))))
    realkey))

(defun eon-org-mark-word-done-add ()
  (save-excursion
    (beginning-of-thing 'word)
    (insert "+")
    (forward-word)
    (insert "+")))

(defun eon-org-mark-word-done-del ()
  (save-excursion
    (beginning-of-thing 'word)
    (backward-char)
    (delete-char 1)
    (forward-word)
    (delete-char 1)))

(defun eon-org-mark-word-done-toggle ()
  (interactive)
  (save-excursion
    (beginning-of-thing 'word)
    (let ((flag1 (= (char-before) ?+)))
      (forward-word)
      (let ((flag2 (= (char-after) ?+)))
	(cond ((and flag1 flag2) (eon-org-mark-word-done-del))
	      ((and (not flag1) (not flag2)) (eon-org-mark-word-done-add))
	      (t (error "无法处理")))))))

(defun eon-org-mark-command ()
  (interactive)
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "d") #'eon-org-mark-word-done-toggle)
    (set-transient-map keymap nil nil nil eon-sub-keymap-waiting-time)))

(defun em-m ()
  (let ((realkey
	 (pcase major-mode
	   ('dired-mode #'dired-mark)
	   ('org-mode #'eon-org-mark-command)
	   ('git-rebase-mode #'git-rebase-edit)
	   (_ #'ignore))))
    realkey))

(defun em-n ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "n"))
	   ('ivy-occur-grep-mode "M-n")
	   ('ivy-occur-mode #'ivy-occur-next-line)
	   ('go-test-mode "M-n")
	   ('comint-mode #'compilation-next-error)
	   (_ "C-n"))))
    realkey))

(defun em-o-command ()
  (interactive)
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "a") #'org-agenda)
    (define-key keymap (kbd "c") #'org-capture)
    (define-key keymap (kbd "e") #'eon-work-open-excel)
    (define-key keymap (kbd "f") #'eon-open-agenda-file)
    (define-key keymap (kbd "n") #'eon-open-notes)
    (pcase major-mode
      ('org-agenda-mode (define-key keymap (kbd "t") #'(lambda ()
							 (interactive)
							 (call-interactively #'org-agenda-todo)
							 (call-interactively #'org-agenda-redo-all))))
      ('magit-repolist-mode (define-key keymap (kbd "g") #'eon-magit-repolist-open-git-http))
      ('org-mode (progn
		   (define-key keymap (kbd "t") #'org-todo)
		   (define-key keymap (kbd "o") #'org-open-at-point))))
    (pcase major-mode
      (_ (set-transient-map keymap nil nil nil eon-sub-keymap-waiting-time)))))

(defun em-o ()
  (let ((realkey
	 (pcase major-mode
	   (_ #'em-o-command))))
    realkey))

(defun em-p ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "p"))
	   ('ivy-occur-grep-mode "M-p")
	   ('ivy-occur-mode #'ivy-occur-previous-line)
	   ('go-test-mode "M-p")
	   ('comint-mode #'compilation-previous-error)
	   (_ "C-p"))))
    realkey))

(defun em-q ()
  (let ((realkey
	 ;; 首先判断minor mode
	 (cond (magit-blob-mode #'magit-kill-this-buffer)
	       ;; 最后判断major mode
	       (t (pcase major-mode
		    ('help-mode #'quit-window)
		    ('image-mode #'quit-window)
		    ('dired-mode #'quit-window)
		    ('comint-mode #'quit-window)
		    ('flycheck-error-list-mode #'quit-window)
		    ('magit-revision-mode #'magit-mode-bury-buffer)
		    ('magit-log-mode #'magit-mode-bury-buffer)
		    ('magit-status-mode #'magit-mode-bury-buffer)
		    ('magit-process-mode #'magit-mode-bury-buffer)
		    ('magit-diff-mode #'magit-mode-bury-buffer)
		    ('magit-log-select-mode #'magit-log-select-quit)
		    ('ivy-occur-mode #'quit-window)
		    ('ivy-occur-grep-mode #'quit-window)
		    ('backtrace-mode #'quit-window)
		    ('debugger-mode #'debugger-quit)
		    ('grep-mode #'quit-window)
		    ('emacs-lisp-compilation-mode #'quit-window)
		    ('messages-buffer-mode #'quit-window)
		    ('treemacs-mode #'treemacs-quit)
		    ('org-agenda-mode #'org-agenda-quit)
		    ('compilation-mode #'quit-window)
		    ('go-test-mode #'quit-window)
  		    (_ (cond ((derived-mode-p 'special-mode) #'quit-window)
			     (t nil))))))))
    realkey))

(defun em-r-command ()
  "如果有region则复制到寄存器，否则从寄存器插入内容。"
  (interactive)
  (if (use-region-p)
      (call-interactively 'copy-to-register)
    (call-interactively 'insert-register)))

(defun em-r ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "r"))
	   ('org-mode #'org-refile)
	   (_ #'em-r-command))))
    realkey))

(defun em-s ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "s"))
	   ('magit-diff-mode (eon-magit-key-infer "s"))
	   ('git-rebase-mode #'git-rebase-squash)
	   ('org-mode #'eon-counsel-outline)
	   (_ "C-s"))))
    realkey))

(defun em-t ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "t"))
	   (_ "C-c t"))))
    realkey))

(defun em-u ()
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "u"))
	   ('dired-mode #'dired-unmark)
	   (_ "C-u"))))
    realkey))

(defun em-x-command ()
  (interactive)
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "s") #'save-buffer)
    (define-key keymap (kbd "c") #'save-buffers-kill-terminal)
    (define-key keymap (kbd "f") #'find-file)
    (define-key keymap (kbd "e") #'eval-last-sexp)
    (define-key keymap (kbd "b") #'switch-to-buffer)
    (define-key keymap (kbd "d") #'dired)
    (define-key keymap (kbd "g") #'magit-status)
    (define-key keymap (kbd "G") #'eon-magit-status-wrapper)
    (define-key keymap (kbd "r s") #'copy-to-register)
    (define-key keymap (kbd "r i") #'insert-register)
    (pcase major-mode
      (_ (set-transient-map keymap nil nil nil eon-sub-keymap-waiting-time)))))

(defun em-x-dired-command ()
  "dired 模式下 x 键特殊处理"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((dired-marker-char dired-del-marker))
      (if (dired-get-marked-files)
	  #'dired-do-flagged-delete
	#'em-x-command))))

(defun em-x (&optional key-list)
  (let ((realkey
	 (pcase major-mode
	   ('dired-mode (em-x-dired-command))
	   (_ #'em-x-command))))
    realkey))

(defun em-z (&optional key-list)
  (let ((realkey
	 (pcase major-mode
	   ('magit-status-mode (eon-magit-key-infer "z"))
	   (_ "z"))))
    realkey))

(defun em-default-return ()
  "默认的 return 处理方式，先换行，再退出 modalka"
  (interactive)
  (em-disable)
  (call-interactively #'newline))

(defun em-return ()
  (let ((realkey
	 (pcase major-mode
	   ('help-mode #'push-button)
	   ('dired-mode #'dired-find-file)
	   ('ivy-occur-mode #'ivy-occur-press-and-switch)
	   ('ivy-occur-grep-mode #'ivy-occur-press-and-switch)
	   ('flycheck-error-list-mode #'flycheck-error-list-goto-error)
	   ('Info-mode #'Info-follow-nearest-node)
	   ('treemacs-mode #'treemacs-RET-action)
	   ('org-agenda-mode #'eon-org-agenda-goto-and-narrow)
	   ('magit-status-mode (eon-magit-key-infer "RET"))
	   ('magit-log-mode (eon-magit-key-infer "RET"))
	   ('magit-log-select-mode #'magit-show-commit)
	   ('compilation-mode #'compile-goto-error)
	   ('comint-mode #'compile-goto-error)
	   ('magit-repolist-mode #'magit-repolist-status)
	   ('xref--xref-buffer-mode #'xref-goto-xref)
	   (_ #'em-default-return))))
    realkey))

(defun em-elisp-backspace ()
  (interactive)
  (em-disable)
  (call-interactively #'backward-delete-char-untabify))

(defun em-default-backspace ()
  (interactive)
  (em-disable)
  (call-interactively #'delete-backward-char))

(defun em-backspace ()
  (let ((realkey
	 (pcase major-mode
	   ('emacs-lisp-mode #'em-elisp-backspace)
	   (_ #'em-default-backspace))))
    realkey))

(provide 'em-keys)

;; Local Variables:
;; read-symbol-shorthands: (("em-" . "eon-modalka-"))
;; End:
