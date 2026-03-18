;;; -*- lexical-binding: t -*-

(use-package make-mode
  :hook
  ;; makefile保存时不再提示错误行
  (makefile-bsdmake-mode . (lambda ()
			     (remove-hook 'write-file-functions
					  'makefile-warn-suspicious-lines
					  t))))

;; 看起来应该是解决emacs输出编译结果时，把颜色控制码直接输出成字符问题的
;; 先放在这里
(use-package ansi-color
  :defer t
  :hook
  (compilation-filter
    .
    (lambda ()
      (let ((buffer-read-only nil))
        (ansi-color-apply-on-region (point-min) (point-max))))))


(provide 'eon-make)
