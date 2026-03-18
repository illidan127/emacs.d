;; -*- lexical-binding: t; -*-

(use-package package-build
  :init
  (setq package-build-recipes-dir (expand-file-name "recipes" user-emacs-directory))
  (setq package-build-archive-dir (expand-file-name "eon-elpa" user-emacs-directory))
  (setq package-build-working-dir
	(if (and (boundp 'no-littering-var-directory) (file-exists-p no-littering-var-directory))
	    (expand-file-name "eon-elpa-working" no-littering-var-directory)
	  (expand-file-name "eon-elpa-working" user-emacs-directory))))

(defun eon-elpa--build-one (recipe &optional force)
  "调用`package-build'按RECIPE构建对应包。
如果FORCE为nil，则仅当RECIPE中版本与archive-contents中版本不一致时才重新构建。"
  (package-build-archive recipe)
  (package-build-cleanup))

(defun eon-elpa-build (recipes &optional force)
  "构建RECIPES指定的包
如果FORCE为nil，则只更新版本有变化的包。"
  (dolist (recipe recipes)
    (eon-elpa--build-one recipe force)))

(defun eon-elpa-build-all (&optional force)
  "重新构建所有包
如果FORCE为nil，则只更新版本有变化的包。"
  (interactive "P")
  (eon-elpa-build (directory-files package-build-recipes-dir nil "^[^.]") force))

(defun eon-elpa-find-missing-recipes ()
  "找出已安装的非内置扩展中在 recipes 目录没有对应配方的包"
  (interactive)
  (let ((installed-packages (package--alist))
        (recipe-files (directory-files package-build-recipes-dir nil "^[^.]"))
        missing-packages)
    (dolist (pkg-desc installed-packages)
      (message "%s" pkg-desc)
      (let* ((pkg-name (symbol-name (car pkg-desc)))
             (pkg-desc (cadr pkg-desc))
             (built-in (eq (package-desc-archive pkg-desc) 'builtin)))
        (when (and (not built-in)
                   (not (member pkg-name recipe-files)))
          (push pkg-name missing-packages))))
    (if missing-packages
        (message "Missing recipes for: %s" (string-join missing-packages ", "))
      (message "All non-built-in packages have corresponding recipes."))
    missing-packages))

(defun eon-elpa-build-ivy ()
  "使用ivy交互式选择要构建的recipe"
  (interactive)
  (let ((recipes (directory-files package-build-recipes-dir nil "^[^.]")))
    (ivy-read "选择要构建的包" recipes
              :action (lambda (recipe)
                        (let ((pkg-dir (expand-file-name recipe package-build-working-dir)))
                          (when (file-exists-p pkg-dir)
                            (delete-directory pkg-dir t))
                          (eon-elpa--build-one recipe t))))))

(provide 'eon-elpa)
