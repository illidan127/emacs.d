;; -*- lexical-binding: t; -*-

(defun eon-avy-kill-actions (pt)
  (interactive)
  t)

(use-package avy
  :config
  (setq avy-keys (string-to-list "asdqweru"))
  (global-set-key (kbd "M-j") #'avy-goto-char-timer)
  (setf (alist-get ?k avy-dispatch-alist) #'eon-avy-kill-actions)
  (setq avy-style 'post))

(provide 'eon-avy)
