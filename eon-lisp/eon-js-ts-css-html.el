;;; -*- lexical-binding: t -*-

;;; javascript/typescript/css/html相关配置

(eon-treesit-enable 'typescript)
(eon-treesit-enable 'tsx)

(add-to-list 'auto-mode-alist '("\\.ts\\'" . typescript-ts-mode))
(add-to-list 'auto-mode-alist '("\\.tsx\\'" . tsx-ts-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . js-ts-mode))

(eon-add-hooks 'typescript-ts-mode-hook 'yas-minor-mode 'lsp-deferred)
(eon-add-hooks 'tsx-ts-mode-hook 'yas-minor-mode 'lsp-deferred)

(use-package js
  :init
  (eon-treesit-enable 'javascript)
  (add-to-list 'eon-treesit-fold-modes 'js-ts-mode)
  :mode
  ("\\.js[x]?\\'" . js-ts-mode)
  :hook
  (js-ts-mode . yas-minor-mode)
  (js-ts-mode . lsp-deferred)
  (js-ts-mode . treesit-fold-mode)
  (js-ts-mode . electric-pair-mode))

(provide 'eon-js-ts-css-html)
