;;; -*- lexical-binding: t -*-

;;; 结合counsel的buffer操作工具

(require 'ivy)
(define-key ivy-mode-map [remap switch-to-buffer] 'persp-ivy-switch-buffer)

(provide 'eon-buffer-op)
