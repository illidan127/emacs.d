;;; -*- lexical-binding: t -*-

;;; c/c++ 代码编辑配置

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
  ;; 默认缩 进 为4空格
  (setq c-ts-mode-indent-offset 4)
  (setq lsp-enable-on-type-formatting nil)
  :hook
  (c++-ts-mode . electric-pair-mode)
  (c++-ts-mode . yas-minor-mode)
  (c++-ts-mode . lsp-deferred)
  (c++-ts-mode . treesit-fold-mode)
  (c-ts-mode . electric-pair-mode)
  (c-ts-mode . yas-minor-mode)
  (c-ts-mode . lsp-deferred)
  (c-ts-mode . treesit-fold-mode)
  )

(provide 'eon-c-c++)
