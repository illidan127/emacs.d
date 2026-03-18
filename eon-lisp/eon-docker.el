;;; -*- lexical-binding: t -*-

(use-package dockerfile-ts-mode
  :ensure nil
  :init
  (eon-treesit-enable 'dockerfile)
  :mode ("/[Dd]ockerfile\\'" . dockerfile-ts-mode)
  :config
  (modify-syntax-entry ?/ "." dockerfile-ts-mode--syntax-table)
  :hook
  (docker-file-ts-mode . yas-minor-mode)
  (docker-file-ts-mode . lsp-deferred))

(provide 'eon-docker)
