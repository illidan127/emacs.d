;;; eon-load-paths.el --- 包加载路径覆盖映射 -*- lexical-binding: t -*-

(require 'use-package)

(defvar eon-package-dirs nil
  "Alist of (package-name . local-directory).
指定后，对应的 use-package 将自动注入 :load-path 指向该目录，
并自动设置 :ensure nil 以避免覆盖本地版本。

示例:
  (setq eon-package-dirs '((vertico . \"~/src/vertico\")))")

(defvar eon--use-package-orig
  (let ((sf (symbol-function 'use-package)))
    (if (eq (car-safe sf) 'macro)
        (cdr sf)
      sf))
  "Original `use-package' macro function, without the `macro' tag.")

(defmacro use-package (name &rest args)
  "增强版 `use-package'，自动从 `eon-package-dirs' 注入 :load-path。"
  (declare (indent 1))
  (when-let ((dir (alist-get name eon-package-dirs)))
    (unless (plist-get args :load-path)
      (setq args (nconc args (list :load-path `(,dir)))))
    (unless (plist-member args :ensure)
      (setq args (nconc args '(:ensure nil)))))
  (apply eon--use-package-orig name args))

(provide 'eon-load-paths)
