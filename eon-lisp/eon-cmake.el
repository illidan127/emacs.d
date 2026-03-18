;;; -*- lexical-binding: t -*-

;; cmake

(use-package
  cmake-mode
  :defer t
  :init
  (eon-treesit-enable 'cmake)
  :after (eon-lsp)
  :config (modify-syntax-entry ?_ "w" cmake-mode-syntax-table)
  :hook
  (cmake-ts-mode . yas-minor-mode)
  (cmake-ts-mode . lsp-deferred))

(provide 'eon-cmake)
