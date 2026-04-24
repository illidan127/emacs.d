;;; -*- lexical-binding: t -*-

;;; 结合counsel的buffer操作工具

(require 'ivy)

;; `ivy-switch-buffer' defaults to `ivy-switch-buffer-occur' (opens ibuffer).
;; `counsel-ibuffer' has no custom occur and uses `ivy--occur-default' instead.
;; Match that so `persp-ivy-switch-buffer' → `ivy-occur' shows `ivy-occur-mode'.
(ivy-set-occur 'ivy-switch-buffer #'ivy--occur-default)
(ivy-set-occur 'ivy-switch-buffer-other-window #'ivy--occur-default)

(define-key ivy-mode-map [remap switch-to-buffer] 'persp-ivy-switch-buffer)

;; 自定义 buffer 注释：只显示 major-mode 与文件路径（非文件为空串）
(with-eval-after-load 'marginalia
  (defun eon-marginalia-annotate-buffer (cand)
    "只显示 major-mode 与文件路径的 buffer 注释。"
    (when-let* ((buf (get-buffer cand)))
      (with-current-buffer buf
        (let* ((mode-name
                (let ((m (symbol-name major-mode)))
                  (if (string-suffix-p "-mode" m)
                      (substring m 0 -5)
                    m)))
               (file-path
                (if-let* ((f (buffer-file-name)))
                    (marginalia--abbreviate-file-name f)
                  "")))
          (marginalia--fields
           (mode-name :width 20 :face 'marginalia-mode)
           (file-path :truncate (max 40 (- (window-width) 40))
                      :face 'marginalia-file-name))))))

  (advice-add 'marginalia-annotate-buffer :override
              #'eon-marginalia-annotate-buffer))

(provide 'eon-buffer-op)
