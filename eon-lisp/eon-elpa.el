;; -*- lexical-binding: t; -*-

(require 'cl-lib)

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

(defun eon-elpa--remote-archive-dir-p (dir)
  "判断 DIR 是否为远程 package archive 路径。"
  (and (stringp dir)
       (or (string-prefix-p "http://" dir)
           (string-prefix-p "https://" dir)
           (string-prefix-p "ftp://" dir))))

(defun eon-elpa--read-archive-contents ()
  "读取 eon-elpa/archive-contents 中的包列表。"
  (let ((file (expand-file-name "archive-contents" package-build-archive-dir)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (cdr (read (current-buffer)))))))

(defun eon-elpa--archive-version (pkg)
  "返回 PKG 在 eon-elpa archive 中的版本，不存在则返回 nil。"
  (when-let ((entry (assq pkg (eon-elpa--read-archive-contents))))
    (aref (cdr entry) 0)))

(defun eon-elpa--package-allowed-p (pkg desc)
  "判断 PKG 是否允许安装（builtin 或在 eon-elpa archive 中）。"
  (or (eq (package-desc-archive desc) 'builtin)
      (package-built-in-p pkg)
      (assq pkg (eon-elpa--read-archive-contents))))

(defun eon-elpa--sanitize-package-archives ()
  "移除 package-archives 中的远程源，仅保留本地 eon-elpa。"
  (setq package-archives
        (cl-remove-if (lambda (archive)
                        (eon-elpa--remote-archive-dir-p (cdr archive)))
                      package-archives)))

(defun eon-elpa--harden-package-sources ()
  "加固 package 安装源，禁止从网络下载或注册远程 archive。"
  (eon-elpa--sanitize-package-archives))

(define-advice package-download-transaction
    (:around (fn &rest args) eon-elpa-block-package-download)
  (error "禁止从网络下载包，请先在 eon-elpa 中构建：%s" (car args)))

(define-advice package-refresh-contents
    (:around (fn &optional async) eon-elpa-package-refresh-contents)
  (let ((remotes (cl-remove-if (lambda (archive)
                                 (not (eon-elpa--remote-archive-dir-p (cdr archive))))
                               package-archives)))
    (when remotes
      (error "禁止刷新远程 package archive: %s"
             (mapconcat (lambda (archive) (car archive)) remotes ", "))))
  (funcall fn async))

(define-advice add-to-list
    (:before (var val &optional _append) eon-elpa-block-remote-archive)
  (when (eq var 'package-archives)
    (let ((dir (cdr-safe val)))
      (when (eon-elpa--remote-archive-dir-p dir)
        (error "禁止添加远程 package archive: %s" dir)))))

(defun eon-elpa-audit-installed-packages ()
  "审计已安装包来源，列出来自非 eon-elpa 且非 builtin 的包。"
  (interactive)
  (let ((violations nil)
        (version-mismatches nil))
    (dolist (entry (package--alist))
      (let* ((pkg (car entry))
             (name (symbol-name pkg))
             (desc (cadr entry))
             (archive (package-desc-archive desc))
             (archive-version (eon-elpa--archive-version pkg))
             (installed-version (package-desc-version desc)))
        (if (not (eon-elpa--package-allowed-p pkg desc))
            (push (cons name (or archive 'unknown)) violations)
          (when (and archive-version
                     (not (version-list-= installed-version archive-version)))
            (push (list name installed-version archive-version)
                  version-mismatches)))))
    (setq violations (nreverse violations)
          version-mismatches (nreverse version-mismatches))
    (if violations
        (progn
          (message "发现 %d 个非本地源包:" (length violations))
          (dolist (v violations)
            (message "  %s <- %s" (car v) (cdr v))))
      (message "审计通过：所有已安装包均在 eon-elpa archive 或为 builtin"))
    (when version-mismatches
      (message "发现 %d 个版本与 eon-elpa 不一致:" (length version-mismatches))
      (dolist (v version-mismatches)
        (message "  %s: 已安装 %s, archive %s"
                 (nth 0 v) (version-to-string (nth 1 v)) (version-to-string (nth 2 v)))))
    (list :violations violations :version-mismatches version-mismatches)))

(eon-elpa--harden-package-sources)

(provide 'eon-elpa)
