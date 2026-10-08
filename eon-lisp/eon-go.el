;;; -*- lexical-binding: t -*-

;;; gopls 没有排除测试文件的配置，客户端统一过滤掉 *_test.go 的位置。
;;; advice 拦截 lsp-find-implementation / lsp-find-references，覆盖 gi/gr、M-x、菜单；
;;; 带前缀参数（C-u）调用时不过滤。

(defun eon-go--show-locs (locs no-filter display-action)
  "展示 LOCS；除非 NO-FILTER，否则过滤掉 *_test.go 的位置。"
  (unless no-filter
    (setq locs
          (seq-filter
           (lambda (loc)
             (not (string-match-p
                   "_test\\.go\\'"
                   (lsp--uri-to-path (lsp--location-uri loc)))))
           locs)))
  (if (seq-empty-p locs)
      (error "Not found for: %s" (or (thing-at-point 'symbol t) ""))
    (lsp-show-xrefs (lsp--locations-to-xref-items locs) display-action t)))

(cl-defun eon-go-find-implementation (&optional no-filter &key display-action)
  "在 Go 项目中查找光标处符号的实现，默认过滤掉 *_test.go。
带前缀参数（C-u）调用时不过滤。"
  (interactive "P")
  (eon-go--show-locs
   (lsp-request "textDocument/implementation"
                (lsp--text-document-position-params))
   no-filter display-action))

(cl-defun eon-go-find-references (&optional no-filter &key display-action)
  "在 Go 项目中查找光标处符号的引用，默认过滤掉 *_test.go。
带前缀参数（C-u）调用时不过滤。"
  (interactive "P")
  (eon-go--show-locs
   (lsp-request "textDocument/references"
                (append (lsp--text-document-position-params)
                        (list :context
                              `(:includeDeclaration
                                ,(lsp-json-bool
                                  (not (or no-filter
                                           lsp-references-exclude-declaration)))))))
   no-filter display-action))

(defun eon-go--interface-method-p ()
  "point 处是否是 Go interface 中声明的方法名。"
  (when (and (derived-mode-p 'go-ts-mode)
             (treesit-available-p)
             (treesit-parser-list))
    (let ((node (treesit-node-at (point))))
      (and node
           (equal (treesit-node-type node) "field_identifier")
           (let ((parent (treesit-node-parent node)))
             (and parent
                  (equal (treesit-node-type parent) "method_elem")))))))

(defun eon-go-find-definition (&optional no-filter)
  "Go 项目中 M-. 的入口。
若 point 位于 interface 中声明的方法名上，则查找其实现
（带前缀参数 C-u 时实现查找不过滤 *_test.go）；否则执行普通定义跳转。"
  (interactive "P")
  (if (eon-go--interface-method-p)
      (eon-go-find-implementation no-filter)
    (lsp-find-definition)))

(defun eon-go--find-implementation-advice (orig &rest args)
  "Go buffer 中改用过滤版实现查找；C-u 时不过滤。"
  (if (derived-mode-p 'go-ts-mode)
      (apply #'eon-go-find-implementation current-prefix-arg args)
    (apply orig args)))

(defun eon-go--find-references-advice (orig &rest args)
  "Go buffer 中改用过滤版引用查找；C-u 时不过滤。"
  (if (derived-mode-p 'go-ts-mode)
      (apply #'eon-go-find-references args)
    (apply orig args)))

(with-eval-after-load 'lsp-mode
  (advice-add 'lsp-find-implementation :around #'eon-go--find-implementation-advice)
  (advice-add 'lsp-find-references :around #'eon-go--find-references-advice))

;;; go 配置
(use-package go-ts-mode
  :init
  (eon-treesit-enable 'go)
  (eon-treesit-enable 'gomod)
  (add-to-list 'eon-treesit-fold-modes 'go-ts-mode)
  :mode
  ("\\.go\\'" . go-ts-mode)
  ("go\\.mod\\'" . go-mod-ts-mode)
  :bind
  (:map go-ts-mode-map
	("M-." . eon-go-find-definition))
  :hook
  (go-ts-mode . yas-minor-mode)
  (go-ts-mode . electric-pair-mode)
  (go-ts-mode . treesit-fold-mode)
  (go-ts-mode . lsp-deferred))

(use-package gotest)

(provide 'eon-go)
