;; -*- lexical-binding: t; -*-

(use-package protobuf-mode
  :init
  (eon-treesit-enable 'cpp)
  (add-to-list 'eon-treesit-fold-modes 'protobuf-ts-mode)
  :mode
  ("\\.proto\\'" . protobuf-ts-mode)
  :hook
  (protobuf-ts-mode . treesit-fold-mode))

(defun eon-protobuf-text-format (start end &optional replace)
  (interactive (list
		(if mark-active
		    (region-beginning)
		  (point-min))
		(if mark-active
		    (region-end)
		  (point-max))
		current-prefix-arg))
  (message "relace %s" replace)
  (let ((command (format "python3 %s" (f-join eon-tools-path "proto-format.py"))))
    (shell-command-on-region start end command t replace)))


(provide 'eon-protobuf)
