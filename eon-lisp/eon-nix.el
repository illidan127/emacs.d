;;; -*- lexical-binding: t -*-

(use-package nix-ts-mode
  :after (eon-lsp)
  :init
  (eon-treesit-enable 'nix)
  (add-to-list 'eon-treesit-fold-modes 'nix-ts-mode)
  :mode "\\.nix\\'"
  :hook
  (nix-ts-mode . electric-pair-mode)
  (nix-ts-mode . yas-minor-mode)
  (nix-ts-mode . treesit-fold-mode)
  (nix-ts-mode . lsp-deferred))

(provide 'eon-nix)
