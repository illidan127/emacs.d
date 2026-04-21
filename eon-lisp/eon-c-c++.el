;;; -*- lexical-binding: t -*-

;;; c/c++ 代码编辑配置

(defun eon-c++-indent-style ()
  "Allman 缩进风格，匹配 .clang-format 配置：
BreakBeforeBraces: Allman, IndentWidth: 4, IndentCaseLabels: false,
NamespaceIndentation: None, AccessModifierOffset: -4"
  (let ((base (alist-get 'bsd (c-ts-mode--indent-styles 'cpp))))
    `(;; NamespaceIndentation: None
      ((n-p-gp nil "declaration_list" "namespace_definition") parent-bol 0)
      ;; 补齐 range-for 的缩进规则：回车后语句体缩进一级，花括号与 for 对齐
      ((match "compound_statement" "for_range_loop") standalone-parent 0)
      ((parent-is "for_range_loop") standalone-parent c-ts-mode-indent-offset)
      ;; IndentCaseLabels: false
      ((n-p-gp "case_statement" "compound_statement" "switch_statement") parent-bol 0)
      ;; AccessModifierOffset: -4
      ((node-is "access_specifier") parent-bol 0)
      ,@base)))

(defun eon-c-c++-use-spaces-for-indent ()
  "C/C++ 缩进使用空格，不使用制表符。"
  (setq-local indent-tabs-mode nil))

(use-package
  clang-format
  :defer t
  :config (setq clang-format-style "file"))

(use-package c-ts-mode
  :ensure nil
  :init
  (eon-treesit-enable 'cpp)
  (eon-treesit-enable 'c)
  (add-to-list 'eon-treesit-fold-modes 'c-ts-mode)
  (add-to-list 'eon-treesit-fold-modes 'c++-ts-mode)
  :mode
  ("\\.c\\'" . c-ts-mode)
  ("\\.cpp\\'" . c++-ts-mode)
  ("\\.h\\'" . c++-ts-mode)
  ("\\.hpp\\'" . c++-ts-mode)
  :config
  (setq c-ts-mode-indent-offset 4)
  (setq c-ts-mode-indent-style #'eon-c++-indent-style)
  (setq lsp-enable-on-type-formatting nil)
  :hook
  (c++-ts-mode . eon-c-c++-use-spaces-for-indent)
  (c++-ts-mode . electric-pair-mode)
  (c++-ts-mode . yas-minor-mode)
  (c++-ts-mode . lsp-deferred)
  (c++-ts-mode . treesit-fold-mode)
  (c-ts-mode . eon-c-c++-use-spaces-for-indent)
  (c-ts-mode . electric-pair-mode)
  (c-ts-mode . yas-minor-mode)
  (c-ts-mode . lsp-deferred)
  (c-ts-mode . treesit-fold-mode)
  )

(provide 'eon-c-c++)
