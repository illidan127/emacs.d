;;; -*- lexical-binding: t -*-

(use-package elisp-mode
  :ensure nil
  :mode ("\\.el\\'" . emacs-lisp-mode)
  :init
  (eon-treesit-enable 'elisp)
  :config
  (modify-syntax-entry ?- "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?> "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?? "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?< "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?/ "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?! "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?- "w" emacs-lisp-mode-syntax-table)
  (modify-syntax-entry ?: "w" emacs-lisp-mode-syntax-table)
  :hook
  (emacs-lisp-mode . prettify-symbols-mode)
  (emacs-lisp-mode . (lambda () (setq prettify-symbols-alist
				 `(("(lambda" . ,(eon-string-to-symbol-list "(λ"))))))
  (emacs-lisp-mode . yas-minor-mode)
  (emacs-lisp-mode . company-mode))

(provide 'eon-lisp)
