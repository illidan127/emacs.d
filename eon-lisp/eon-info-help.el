;; -*- lexical-binding: t; -*-

(use-package info+
  :bind
  (:map Info-mode-map
	("B" . #'Info-history-back)
	("F" . #'Info-history-forward)))

(use-package help-mode
  :ensure nil
  :bind
  (:map help-mode-map
	("B" . #'help-go-back)
	("F" . #'help-go-forward)))

(provide 'eon-info-help)
