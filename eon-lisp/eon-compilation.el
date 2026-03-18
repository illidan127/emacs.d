;;; -*- lexical-binding: t -*-
;; 根据目录，自动编译

(setq compilation-scroll-output t)

(defun eon-create-commands-from-shell-aliases ()
  "Create Emacs commands from shell aliases starting with 'm_'."
  (interactive)
  (let* ((shell-command-switch "-ic")
	 (alias-output (shell-command-to-string "alias"))
         (aliases (split-string alias-output "\n" t)))
    (dolist (alias aliases)
      (when (string-match "^alias \\(m_[^=]+\\)=" alias)
        (let* ((alias-name (match-string 1 alias))
               (command-name (intern alias-name))
               (command-body (format "shell-command \"%s\"" alias-name)))
          (eval `(defun ,command-name ()
                   ,(format "Execute shell alias %s" alias-name)
                   (interactive)
		   (let ((shell-command-switch "-ic"))
                     (compile ,alias-name t))))
          (message "创建编译命令: %s" alias-name))))))

(provide 'eon-compilation)
