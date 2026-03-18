;;; -*- lexical-binding: t -*-

;;; emacs中区域选择等操作

(defvar eon-first-mark-point nil
  "设置mark时光标位置")

(defun eon-line-pos-for-point (position)
  "获取POSITION所在行的行首与行尾位置"
  (interactive)
  (save-excursion
    (goto-char position)
    (let
	(
         (beg (line-beginning-position))
         (end (line-end-position)))
      (cons beg end))))

(defun eon-update-region ()
  (when
      (and mark-active
	   (not (region-noncontiguous-p))
	   (not (null eon-first-mark-point)))
    (let*
	(
         (current-pos (point))
         (current-line (eon-line-pos-for-point current-pos))
         (mark-line (eon-line-pos-for-point eon-first-mark-point)))
      (if (< current-pos eon-first-mark-point)
          (progn
            (set-mark (cdr mark-line))
            (forward-line 0))
        (progn
          (set-mark (car mark-line))
          (goto-char (cdr current-line)))))))

(defun eon-next-line (arg)
  "自定义的向前移动n行，移动后将智能更新选区"
  (interactive "^p")
  (line-move arg t)
  (eon-update-region))

(defun eon-previous-line (arg)
  "自定义的向前移动n行，移动后将智能更新选区"
  (interactive "^p")
  (line-move (* -1 arg) t)
  (eon-update-region))

(define-key global-map [remap next-line] 'eon-next-line)
(define-key global-map [remap previous-line] 'eon-previous-line)

(add-hook
 'deactivate-mark-hook
 (lambda () (setq eon-first-mark-point nil)))

(defun eon-mark-lines ()
  "选中光标所在整行"
  (interactive)
  (when (not (use-region-p))
    (setq eon-first-mark-point (point))
    (let
	((current-line (eon-line-pos-for-point eon-first-mark-point)))
      (set-mark (car current-line))
      (goto-char (cdr current-line)))))

(define-key global-map (kbd "C-M-v") #'eon-mark-lines)

(defun eon-smart-kill (&optional arg)
  "智能剪切命令，如果有选区，则执行`kill-region`
如果是在当前行行尾，则将光标移到下一行，并执行 delete-indentation
否则执行普通的kill-line"
  (interactive "P")
  (cond ((use-region-p) (kill-region (region-beginning) (region-end)))
	((eolp)
	 (forward-char 1)
	 (delete-indentation)
	 (if (bolp)
	     (indent-according-to-mode)))
	(t
	 (kill-line arg))))
(define-key global-map [remap kill-line] 'eon-smart-kill)

(use-package
  expand-region
  :defer t
  :diminish
  :bind ("C-=" . er/expand-region))

(provide 'eon-selection-op)
