;;; -*- lexical-binding: t -*-

;;; shell-script相关

(use-package sh-script
  :init
  (eon-treesit-enable 'bash)
  :mode ("bashrc\\'" . bash-ts-mode)
  ("\\.sh\\'" . bash-ts-mode)
  :interpreter ("bash" . bash-ts-mode)
  :hook (bash-ts-mode . yas-minor-mode)
  (bash-ts-mode . electric-pair-mode)
  (bash-ts-mode . lsp-deferred))

(provide 'eon-bash)
