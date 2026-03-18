;;; -*- lexical-binding: t -*-

(let ((min-supported-version "29.0"))
  (when (version< emacs-version min-supported-version)
    (signal
     'version-not-match
     `(,(format "Emacs版本太低，需要%s以上版本，当前%s"
		min-supported-version
		emacs-version)))
    (kill-emacs)))

;; 某函数被调用时触发中断，打印调用栈
;; (debug-on-entry 'file-exists-p)

;; (add-variable-watcher 'auto-mode-alist #'(lambda (sym new oper where)
;; 					   (message "Variable %s changed to %s in %s"
;; 						    sym new (or (car (backtrace-frames)) "unknown location"))))

(setq current-language-environment "UTF-8")

(defun eon-max-gc-limit ()
  (setq gc-cons-threshold most-positive-fixnum))

(defun eon-reset-gc-limit ()
  (setq gc-cons-threshold (* 100 1024 1024)))

;; lsp-mode 性能考虑
(setenv "LSP_USE_PLISTS" "true")

(add-hook 'minibuffer-setup-hook #'eon-max-gc-limit)
(add-hook 'minibuffer-exit-hook #'eon-reset-gc-limit)
(add-hook 'after-init-hook #'eon-reset-gc-limit)
