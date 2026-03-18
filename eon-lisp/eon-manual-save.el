;;;eon-manual-save.el --- Manual save mode -*- lexical-binding: t -*-

;; 重新绑定C-x C-s到 eon-manual-save-buffer
;; 用以区别手动保存与自动保存
;; 自动保存使用buffer-save

(defvar eon-manual-save-hook-table nil)

(defun eon-make-manual-save-hook (the-mode-name)
  "定义用于各个模式下手动保存前的挂钩函数列表，
生成eon-manual-save-<mode-name>-hook挂钩函数列表。
可向其中加入手动保存时要执行的命令，无论buffer是否修改，
执行手动保存时，hook中命令都会执行。

若某主模式需要使eon-manual-save-mode辅模式生效，
必须先调用此函数，然后再向生成的挂钩函数列表中注册挂钩函数。"
  (let
      (
       (hook
        (intern
         (concat
          "eon-manual-save-"
          (symbol-name the-mode-name)
          "-hook"))))
    (eval
     `
     (progn
       (defcustom ,hook nil
         "手动保存前执行代码"
         :type 'hook
         :group 'eon)
       (add-to-list
        'eon-manual-save-hook-table
        '(,the-mode-name . ,hook))))))

(defun eon-manual-save-buffer (&optional arg)
  "手动保存代码的命令，用以区其他自动保存插件调用save-buffer保存
此命令可在保存前，调用譬如格式化代码之类的操作。而自动保存时如果直接格式化
代码，可能会引起不必要的麻烦"
  (interactive "p")
  (message "当前主模式 %s" major-mode)
  (if
      (and (buffer-file-name)
	   (cdr (assoc major-mode eon-manual-save-hook-table)))
      (progn
	(run-hooks (alist-get major-mode eon-manual-save-hook-table))))
  (save-buffer arg))

(defun eon-enable-manual-save (mode format-function)
  "手动保存时自动格式化功能集成函数，消除模板代码
还是可以通过
(eon-make-manual-save-hook 'xxx-mode)
(add-hook 'eon-manual-save-xxx-mode-hook 'format-function)
(add-hook 'xxx-mode-hook 'eon-manual-save-mode)
来完成对应功能
"
  (eon-make-manual-save-hook mode)
  (let
      (
       (save-hook
        (intern
         (concat "eon-manual-save-" (symbol-name mode) "-hook")))
       (mode-hook (intern (concat (symbol-name mode) "-hook"))))
    (add-hook save-hook format-function)
    (add-hook mode-hook 'eon-manual-save-mode)))


(define-minor-mode eon-manual-save-mode
  "手动保存缓冲区模式"
  :init-value nil
  :lighter ""
  :keymap `((,(kbd "C-x C-s") . eon-manual-save-buffer))
  :group 'eon)

(provide 'eon-manual-save)
