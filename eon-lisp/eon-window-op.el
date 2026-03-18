;;; -*- lexical-binding: t -*-

;;; 窗口操作
;; 采用windmove包，结合vim的快捷键

;; (use-package ace-window
;;   :diminish t
;;   :demand t)

(use-package windmove
  :diminish t
  :demand t)

(defun eon-windmove (direction)
  (pcase direction
    ('left (windmove-left))
    ('right (windmove-right))
    ('up (windmove-up))
    ('down (windmove-down))))

(defun eon-try-modalka-enable ()
  (if (functionp #'eon-modalka-enable)
      (eon-modalka-enable)))

(defun eon-windmove-right ()
    (interactive)
    (eon-try-modalka-enable)
    (eon-windmove 'right))

(defun eon-windmove-left ()
    (interactive)
    (eon-try-modalka-enable)
    (eon-windmove 'left))

(defun eon-windmove-up ()
    (interactive)
    (eon-try-modalka-enable)
    (eon-windmove 'up))

(defun eon-windmove-down ()
    (interactive)
    (eon-try-modalka-enable)
    (eon-windmove 'down))

(defun eon-delete-window ()
    (interactive)
    (eon-try-modalka-enable)
    (delete-window))

(defvar eon-window-op-map
  (let ((map (make-sparse-keymap)))
    ;; 窗口增减
    (define-key map "s" #'split-window-vertically)
    (define-key map "v" #'split-window-horizontally)
    (define-key map "o" #'delete-other-windows)
    (define-key map "c" #'eon-delete-window)
    (define-key map "f" #'eon-windmove-right)
    (define-key map "b" #'eon-windmove-left)
    (define-key map "n" #'eon-windmove-down)
    (define-key map "p" #'eon-windmove-up)
    map)
  "EON窗口移动指令")
(global-unset-key (kbd "C-w"))
(define-key global-map (kbd "C-w") eon-window-op-map)


(provide 'eon-window-op)
