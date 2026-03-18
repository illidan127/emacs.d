;;; -*- lexical-binding: t -*-

;;; dart/flutter 配置


(advice-add
  'lsp-completion--looking-back-trigger-characterp
  :around
  (defun
    lsp-completion--looking-back-trigger-characterp@fix-dart-trigger-characters
    (orig-fn trigger-characters)
    (funcall orig-fn
      (if (and (derived-mode-p 'dart-mode) (not trigger-characters))
        ["." "=" "(" "$"]
        trigger-characters))))


(use-package hover)

(use-package
  lsp-dart
  :hook
  (dart-mode
    .
    (lambda ()
      (setq company-backends (list 'company-capf))
      (setq-local company-minimum-prefix-length 1))))

(provide 'eon-dart)
