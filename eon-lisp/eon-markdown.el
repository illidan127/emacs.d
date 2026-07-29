;;; -*- lexical-binding: t -*-

(use-package markdown-mode
  :mode
  ("README\\.md\\'" . gfm-mode)
  ("\\.md\\'" . gfm-mode)
  :init (setq markdown-command "marked"))

(use-package poly-markdown)
