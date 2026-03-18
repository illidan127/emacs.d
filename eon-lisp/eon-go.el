;;; -*- lexical-binding: t -*-

;;; go 配置
(use-package go-ts-mode
  :init
  (eon-treesit-enable 'go)
  (eon-treesit-enable 'gomod)
  (add-to-list 'eon-treesit-fold-modes 'go-ts-mode)
  :mode
  ("\\.go\\'" . go-ts-mode)
  ("go\\.mod\\'" . go-mod-ts-mode)
  :bind
  (:map go-ts-mode-map
	("M-." . eon-lsp-smart-find))
  :hook
  (go-ts-mode . yas-minor-mode)
  (go-ts-mode . electric-pair-mode)
  (go-ts-mode . treesit-fold-mode)
  (go-ts-mode . lsp-deferred))

(use-package gotest)

(provide 'eon-go)
