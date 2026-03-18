;;; -*- lexical-binding: t -*-

;;; 依赖包安装源设置，以及基础环境包安装

;; 相关源配置
;; (setq package-archives '(("gnu" . "https://mirrors.ustc.edu.cn/elpa/gnu/")
;;                          ("melpa" . "https://mirrors.ustc.edu.cn/elpa/melpa/")
;;                          ("nongnu" . "https://mirrors.ustc.edu.cn/elpa/nongnu/")))

(setq package-archives '())

;; 添加本地源
(let ((eon-elpa (expand-file-name "eon-elpa" user-emacs-directory)))
  (when (file-exists-p (expand-file-name "archive-contents" eon-elpa))
    (add-to-list 'package-archives `("eon-elpa/" . ,eon-elpa))
    (setq package-archive-priorities '(("eon-elpa" . 1000)))))

;; 在更新包列表前，先刷新一下自建仓库
;; (define-advice package-refresh-contents (:before (&optional async) eon-package-refresh-contents)
;;   (when (fboundp 'magit-submodule-update)
;;     (let ((default-directory user-emacs-directory))
;;       (magit-submodule-update "eon-elpa" "--remote"))))

;; 停止emacs在init.el中乱填信息
(define-advice custom-save-variables (:around (origin &optional rest) eon-custom-save-variables)
  nil)
(define-advice custom-save-faces (:around (origin &optional rest) eon-custom-save-faces)
  nil)

(package-initialize)

(require 'use-package-ensure)
(setq use-package-always-ensure t) ;; 默认给所有 use-package 增加 :ensure t
(setq debug-on-error nil)

;; 忘了有啥用
(setq native-comp-jit-compilation-deny-list '("/xr\\.el$"))

;; 尽早加载
(use-package no-littering
  :init
  (setq no-littering-etc-directory
        (expand-file-name "config/" user-emacs-directory))
  (setq no-littering-var-directory
        (expand-file-name "data/" user-emacs-directory)))

(use-package diminish)

(require 'eon-elpa)


(defvar eon-cpu-core
  (string-to-number
   (let ((nproc (executable-find "nproc")))
     (if nproc
         (shell-command-to-string nproc)
       "1")))
  "CPU核心数")

(use-package f)

(use-package exec-path-from-shell
  :config
  (exec-path-from-shell-initialize))

;; 特殊情况处理，mac上使用图形界面启动emacs时，LANG设置有问题（en_US.UTF-8）。原因暂时不明
;; 怀疑与launched配置有关，暂不细究
;; 设置为 en_US.UTF-8 会使 dired 的列表排序有问题，部分文件夹排在点开头文件前面
(if (eq system-type 'darwin)
    (setenv "LANG" "zh_CN.UTF-8"))

(setq eon-tools-path (f-join user-emacs-directory "tools"))

(provide 'eon-env)
