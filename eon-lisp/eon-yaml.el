;;; -*- lexical-binding: t -*-

;; yaml

(eon-treesit-enable 'yaml)

(use-package yaml-ts-mode
  :init
  (add-to-list 'eon-treesit-fold-modes 'yaml-ts-mode)
  :mode
  ("\\.yaml\\'" . yaml-ts-mode)
  ("\\.yml\\'" . yaml-ts-mode)
  :hook
  (yaml-ts-mode . treesit-fold-mode))

(provide 'eon-yaml)
