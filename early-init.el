;;; -*- lexical-binding: t -*-

(let ((min-supported-version "29.0"))
  (when (version< emacs-version min-supported-version)
    (signal
     'version-not-match
     `(,(format "Emacs版本太低，需要%s以上版本，当前%s"
		min-supported-version
		emacs-version)))
    (kill-emacs)))

;; 某函数被调用时触发中断，打印调用栈
;; (debug-on-entry 'file-exists-p)

;; (add-variable-watcher 'auto-mode-alist #'(lambda (sym new oper where)
;; 					   (message "Variable %s changed to %s in %s"
;; 						    sym new (or (car (backtrace-frames)) "unknown location"))))

(setq current-language-environment "UTF-8")

(defun eon-max-gc-limit ()
  (setq gc-cons-threshold most-positive-fixnum))

(defun eon-reset-gc-limit ()
  (setq gc-cons-threshold (* 100 1024 1024)))

;; lsp-mode 性能考虑
(setenv "LSP_USE_PLISTS" "true")

(add-hook 'minibuffer-setup-hook #'eon-max-gc-limit)
(add-hook 'minibuffer-exit-hook #'eon-reset-gc-limit)
(add-hook 'after-init-hook #'eon-reset-gc-limit)

;;; 窗口 / frame 最大化

;; 启动时的首个 frame 直接最大化。
;; 放在 early-init 里，`frame-initialize' 会在创建初始 frame 时原生应用该参数，
;; 不会有“先按默认尺寸出现再放大”的闪烁。注意这里用的是 `initial-frame-alist'
;; 而不是 `default-frame-alist'，后者会被子 frame 继承（见下）。
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

;; 之后新建的顶层 frame 也自动最大化。
;; 带 `parent-frame' 参数的是子 frame（lsp-ui-doc、posframe、corfu、company-posframe
;; 等），必须跳过：Emacs 31 的 NS 构建中 `alter-fullscreen-frames' 默认为 `inhibit'，
;; 子 frame 一旦继承 fullscreen，`set-frame-size' 会被直接忽略，表现为只显示一个
;; 1x1 的空框。因此不要把 `(fullscreen . maximized)' 放进 `default-frame-alist'。
(defun eon-maximize-frame (frame)
  "最大化顶层 FRAME，子 frame 不做处理。"
  (unless (frame-parameter frame 'parent-frame)
    (set-frame-parameter frame 'fullscreen 'maximized)))

;; 在 early-init 里加入，这样初始 frame 也会走到该 hook。
(add-hook 'after-make-frame-functions #'eon-maximize-frame)
