;;; -*- lexical-binding: t -*-

;;; 结合counsel的buffer操作工具

(require 'ivy)

;; `ivy-switch-buffer' defaults to `ivy-switch-buffer-occur' (opens ibuffer).
;; `counsel-ibuffer' has no custom occur and uses `ivy--occur-default' instead.
;; Match that so `persp-ivy-switch-buffer' → `ivy-occur' shows `ivy-occur-mode'.
(ivy-set-occur 'ivy-switch-buffer #'ivy--occur-default)
(ivy-set-occur 'ivy-switch-buffer-other-window #'ivy--occur-default)

(define-key ivy-mode-map [remap switch-to-buffer] 'persp-ivy-switch-buffer)

(provide 'eon-buffer-op)
