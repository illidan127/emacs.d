;;; -*- lexical-binding: t -*-

(use-package lua-ts-mode
  :init
  ;;; 欺骗 lsp-lua 中检测lua lsp的函数
  (setq lsp-clients-lua-language-server-main-location user-emacs-directory)
  (setq lsp-clients-lua-language-server-bin user-emacs-directory)
  (add-to-list 'eon-treesit-fold-modes 'lua-ts-mode)

  ;;; 通过nix直接安装
  :after (lsp-mode)
  :config
  :mode ("\\.lua\\'" . lua-ts-mode)
  :hook (lua-ts-mode . lsp-deferred))

(provide 'eon-lua)
