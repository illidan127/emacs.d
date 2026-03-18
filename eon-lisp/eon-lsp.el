;;; -*- lexical-binding: t -*-

(require 'eon-lib)

;; 取消全局绑定
(unbind-key (kbd "M-.") 'global-map)
(unbind-key (kbd "M-,") 'global-map)

(use-package lsp-mode
  :config
  (setq lsp-enable-symbol-highlighting nil))

(setq lsp-headerline-breadcrumb-enable nil)

(use-package lsp-ui
  :init
  (setq lsp-ui-doc-show-with-cursor t	; 随光标显示文档，例如光标在c++ include 上面时，显示头文件位置
	lsp-ui-doc-position 'top)	; 文档显示位置
  :config
  (define-key lsp-ui-mode-map [remap xref-find-definitions] #'lsp-find-definition)
  (define-key lsp-ui-mode-map [remap xref-find-references] #'lsp-find-references))

(use-package flycheck)

(use-package lsp-treemacs)

(use-package treemacs
  :config (setq treemacs-no-delete-other-windows nil))

(use-package lsp-ivy
  :after (lsp-mode))

(use-package dap-mode)

(use-package ivy-xref
  :config
  (setq xref-show-xrefs-function #'ivy-xref-show-xrefs))

(define-key prog-mode-map (kbd "M-.") #'xref-find-definitions)
(define-key prog-mode-map (kbd "M-/") #'xref-find-references)
(define-key prog-mode-map (kbd "M-,") #'xref-go-back)


;;; 改写原来的lsp-find-locations，seq-empty-p loc满足时，抛出错误而非
(cl-defun lsp-find-locations (method &optional extra &key display-action references?)
  "Send request named METHOD and get cross references of the symbol under point.
EXTRA is a plist of extra parameters.
REFERENCES? t when METHOD returns references."
  (let ((loc (lsp-request method
                          (append (lsp--text-document-position-params) extra))))
    (if (seq-empty-p loc)
        (error "Not found for: %s" (or (thing-at-point 'symbol t) ""))
      (lsp-show-xrefs (lsp--locations-to-xref-items loc) display-action references?))))


(cl-defun eon-lsp-smart-find (&key display-action)
  (interactive)
  (eon-first-success
   (lsp-find-locations "textDocument/implementation" nil :display-action display-action :references? t)
   (lsp-find-locations "textDocument/definition" nil :display-action display-action)))


(provide 'eon-lsp)
