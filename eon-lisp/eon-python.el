;;; -*- lexical-binding: t -*-

;;; python

(use-package python-ts-mode
  :ensure nil
  :init
  (eon-treesit-enable 'python)
  (add-to-list 'eon-treesit-fold-modes 'python-ts-mode)
  :after (eon-lsp)
  :mode
  ("\\.py\\'" . python-ts-mode)
  :hook (python-ts-mode . lsp-deferred))

(provide 'eon-python)
