;;; -*- lexical-binding: t -*-

;;; 一般配置项

;; 无启动界面
(setq inhibit-splash-screen 1)

;; 无工具栏
(when (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))

;; 光标
(setq-default cursor-type 'bar)


;; 无菜单栏
(when (fboundp 'menu-bar-mode)
  (menu-bar-mode -1))

;; 无响铃
(setq ring-bell-function 'ignore)

;; 正常的滚动效果，光标到最后一行时，不会滚动半屏
(setq
 scroll-margin 0
 scroll-conservatively 0
 scroll-preserve-screen-position nil)

;; 翻页到底或到顶时将光标也移到底或顶
(setq scroll-error-top-bottom t)

;; 无滚动条
(scroll-bar-mode -1)

;; y/n代替yes/no
(fset 'yes-or-no-p 'y-or-n-p)

;; fontset 名称可以由 script-representative-chars 得到
;; (if (eq system-type 'darwin)
;;     (progn
;;       (set-face-attribute 'default nil :height 160)
;;       (set-fontset-font t 'han (font-spec :family "Source Han Sans CN")))
;;   (progn
;;     (set-face-attribute 'default nil)
;;     (set-fontset-font t 'han (font-spec :family "Source Han Sans CN"))))

(tooltip-mode -1)
(global-hl-line-mode 1)

;; 放大整体字体
(face-spec-set 'default `((t (:height 144))))

;; 启动最大化
(add-to-list 'default-frame-alist '(fullscreen . maximized))

;; 主题加载
(add-to-list
 'custom-theme-load-path
 (expand-file-name "eon-lisp" user-emacs-directory))
(load-theme 'eon-dust t)

;; 编码识别配置
(prefer-coding-system 'cp950)
(prefer-coding-system 'gb2312)
(prefer-coding-system 'cp936)
(prefer-coding-system 'gb18030)
(prefer-coding-system 'utf-16)
(prefer-coding-system 'utf-8-dos)
(prefer-coding-system 'utf-8-unix)

;; 退出时询问
(setq confirm-kill-emacs
      (lambda (_) (y-or-n-p-with-timeout "退出？: " 10 "y")))

;; 行号列号
(line-number-mode t)
(column-number-mode t)
;; 文件位置
(size-indication-mode t)

;; 启用upcase-region
(put 'upcase-region 'disabled nil)

;; 启动时不再使用 *scratch*
(setq initial-buffer-choice "~/temp/temp")
(add-hook 'emacs-startup-hook #'(lambda () (if (get-buffer "*scratch*")
					  (kill-buffer "*scratch*"))))

(defun eon-string-to-symbol-list (str)
  "将字符串 STR 转换为符号列表，每个字符之间插入 (Br . Bl) 元组"
  (let ((result '()))
    (dotimes (i (length str))
      (push (aref str i) result)
      (when (< i (1- (length str)))
        (push '(Br . Bl) result)))
    (nreverse result)))

(global-set-key (kbd "C-<left>") #'other-frame)
(global-set-key (kbd "C-<right>") #'other-frame)

(provide 'eon-generic)
