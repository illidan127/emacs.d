;;; -*- lexical-binding: t -*-

(use-package
  nginx-mode
  :hook
  (nginx-mode . hs-minor-mode))

(provide 'eon-nginx)
