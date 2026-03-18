;; -*- lexical-binding: t; -*-

(use-package graphviz-dot-mode
  :requires (flycheck)
  :config
  (setq graphviz-dot-indent-width 4)
  :hook
  (graphviz-dot-mode . flycheck-mode))

(provide 'eon-dot)
