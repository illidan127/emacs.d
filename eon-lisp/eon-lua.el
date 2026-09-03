;;; -*- lexical-binding: t -*-

(use-package lua-ts-mode
  :init
  ;;; 通过 nix 安装 lua-language-server，显式指向二进制。
  ;;; 新版 lsp-lua 用 executable-find 检测 bin，不能再指向目录。
  (setq lsp-clients-lua-language-server-bin
        (expand-file-name "bin/lua-language-server" "~/.nix-profile"))
  (add-to-list 'eon-treesit-fold-modes 'lua-ts-mode)

  :after (lsp-mode)
  :config
  :mode ("\\.lua\\'" . lua-ts-mode)
  :hook (lua-ts-mode . lsp-deferred))

(provide 'eon-lua)
