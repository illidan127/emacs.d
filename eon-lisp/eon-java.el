;;; -*- lexical-binding: t -*-

(eon-treesit-enable 'java)

(add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode))

(defun eon-java-config ()
  "java配置"
  (indent-tabs-mode -1))

(use-package lsp-java)

(eon-add-hooks 'java-ts-mode-hook 'yas-minor-mode 'eon-java-config 'lsp-deferred)

(provide 'eon-java)
