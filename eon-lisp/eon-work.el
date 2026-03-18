;;; -*- lexical-binding: t -*-

;; 工作相关的一些功能
(require 'cl-lib)

(defun ew-open-excel ()
  (interactive)
  (browse-url "https://doc.weixin.qq.com/sheet/e3_AH4AUgbdAFwfvl4a15IQdKhn2yoMO?tab=ws6akb"))

(define-key global-map (kbd "C-c o e") #'ew-open-excel)

(defvar ewm-list nil
  "模块列表")

(defvar ew-current-module nil)

(setq ewm-list (with-temp-buffer
		 (let ((module-file (f-join (getenv "HOME") ".emacs.d" "data" "eon-work-module.el")))
		   (if (file-exists-p module-file)
		       (progn
			 (insert-file-contents module-file)
			 (eval (read (current-buffer))))
		     '()))))

(defun ewm--prompt-module nil
  (let ((inhibit-quit t)
	result)
    (unless (with-local-quit
	      (ivy-read "选择模块："
			(cl-remove-duplicates
			 (mapcar #'(lambda (item)
				     (plist-get item '模块))
				 ewm-list)
			 :test #'string-equal)
			:caller 'ewm--prompt-module
			:action #'(lambda (item) (setq result item))))
      (setq quit-flag nil))
    result))

(defun ewm-open (module)
  "打开项目相关页面"
  (interactive
   (list (ewm--prompt-module)))
  (if module
      (progn
	(setq ew-current-module module)
	(ewm-menu))))


(transient-define-prefix ewm-menu ()
  "工作模块跳转菜单"
  ["国家"
   ("z" "国内" "国内")
   ("x" "新加坡" "新加坡")
   ("h" "韩国" "韩国")
   ("y" "印度" "印度")
   ("n" "印尼" "印尼")
   ("d" "德国" "德国")
   ("m" "美国" "美国")]
  [["跳转地址"
    ("g" "git 仓库" ew-open-git)
    ("k" "k8s 地址" ew-open-k8s)
    ("l" "日志地址" ew-open-log)
    ("j" "monitor 监控" ew-open-monitor)
    ("c" "流水线" ew-open-cicd)
    ("q" "七彩石" ew-open-rainbow)]]
  (interactive)
  (transient-setup 'ewm-menu))

(defun ewm-menu-arguments nil
  (transient-args 'ewm-menu))

(defun ew-find-entry (country field module)
  (if (not country)
      (setq country "国内"))
  (message "%s %s %s" country module field)
  (let ((entry-item
	 (seq-filter
	  #'(lambda (item)
	      (and (string-equal (plist-get item '地区) country)
		   (string-equal (plist-get item '模块) module)))
	  ewm-list)))
    (if entry-item
	(plist-get (car entry-item) field))))

(defun ew-open-git (&optional args)
  (interactive (list (ewm-menu-arguments)))
  (browse-url (ew-find-entry (car args) '代码仓库 ew-current-module)))

(defun ew-open-monitor (&optional args)
  (interactive (list (ewm-menu-arguments)))
  (browse-url (ew-find-entry (car args) 'monitor ew-current-module)))

(defun ew-open-cicd (&optional args)
  (interactive (list (ewm-menu-arguments)))
(browse-url (ew-find-entry (car args) '流水线 ew-current-module)))

(defun ew-open-rainbow (&optional args)
  (interactive (list (ewm-menu-arguments)))
  (browse-url (ew-find-entry (car args) '七彩石 ew-current-module)))

(defun ew-open-k8s (&optional args)
  (interactive (list (ewm-menu-arguments)))
  (browse-url (ew-find-entry (car args) 'k8s ew-current-module)))

(defun ew-open-log (&optional args)
  (interactive (list (ewm-menu-arguments)))
  (browse-url (ew-find-entry (car args) '日志 ew-current-module)))

(provide 'eon-work)

;; Local Variables:
;; read-symbol-shorthands: (("ew-" . "eon-work-") ("ewm-" . "eon-work-module-"))
;; End:
