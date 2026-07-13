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

(defun eon-elpa--build-one (recipe)
  "调用`package-build'按RECIPE构建对应包。"
  (package-build-archive recipe)
  (package-build-cleanup))

(defun eon-elpa-build (recipes)
  "构建RECIPES指定的包。"
  (dolist (recipe recipes)
    (eon-elpa--build-one recipe)))

(defun eon-elpa-build-all ()
  "重新构建所有包。"
  (interactive)
  (eon-elpa-build (directory-files package-build-recipes-dir nil "^[^.]")))

(defun eon-elpa-find-missing-recipes ()
  "找出已安装的非内置扩展中在 recipes 目录没有对应配方的包"
  (interactive)
  (let ((installed-packages (package--alist))
        (recipe-files (directory-files package-build-recipes-dir nil "^[^.]"))
        missing-packages)
    (dolist (pkg-desc installed-packages)
      (let* ((pkg-name (symbol-name (car pkg-desc)))
             (desc (cadr pkg-desc))
             (built-in (eq (package-desc-archive desc) 'builtin)))
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
                          (eon-elpa--build-one recipe))))))

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

(define-advice package-download-transaction
    (:around (fn &rest args) eon-elpa-block-package-download)
  (let ((pkgs (car args)))
    (dolist (pkg pkgs)
      (when-let* ((archive-name (package-desc-archive pkg))
                  (archive-dir (cdr (assoc archive-name package-archives)))
                  ((eon-elpa--remote-archive-dir-p archive-dir)))
        (error "禁止从远程源下载包 %s: %s"
               (package-desc-name pkg) archive-name))))
  (apply fn args))

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

(defun eon-elpa--async-fetch-recipe (recipe-name on-done)
  "异步拉取 RECIPE-NAME 的源码。
ON-DONE 接收 (RECIPE-NAME ERROR-MSG)，成功时 ERROR-MSG 为 nil。"
  (condition-case err
      (let* ((rcp (package-recipe-lookup recipe-name))
             (dir (package-recipe--working-tree rcp))
             (url (oref rcp url))
             (git-dir (expand-file-name ".git" dir)))
        (if (file-exists-p git-dir)
            ;; 已有仓库 → 异步 fetch
            (make-process
             :name (format "eon-elpa-fetch-%s" recipe-name)
             :command `("git" "-C" ,dir "fetch" "-f" "--tags" "origin")
             :buffer (generate-new-buffer
                      (format " *eon-elpa-fetch-%s*" recipe-name))
             :connection-type 'pipe
             :noquery t
             :sentinel (eon-elpa--make-fetch-sentinel recipe-name on-done))
          ;; 新仓库 → 异步 clone
          (when (file-exists-p dir)
            (delete-directory dir t))
          (make-directory package-build-working-dir t)
          (make-process
           :name (format "eon-elpa-clone-%s" recipe-name)
           :command `("git" "clone" "--filter=blob:none" ,url ,dir)
           :buffer (generate-new-buffer
                    (format " *eon-elpa-clone-%s*" recipe-name))
           :connection-type 'pipe
           :noquery t
           :sentinel (eon-elpa--make-fetch-sentinel recipe-name on-done))))
    (error
     (funcall on-done recipe-name (error-message-string err)))))

(defun eon-elpa--make-fetch-sentinel (recipe-name on-done)
  "为异步 fetch/clone 进程创建 sentinel。"
  (lambda (p _event)
    (let ((ok (eq 0 (process-exit-status p)))
          (err (unless (eq 0 (process-exit-status p))
                 (with-current-buffer (process-buffer p)
                   (goto-char (point-max))
                   (forward-line -1)
                   (string-trim
                    (buffer-substring (line-beginning-position)
                                      (line-end-position)))))))
      (kill-buffer (process-buffer p))
      (funcall on-done recipe-name (unless ok err)))))

(defun eon-elpa-build-all-async ()
  "异步拉取所有包源码，全部完成后统一构建。"
  (interactive)
  (let* ((recipes (directory-files package-build-recipes-dir nil "^[^.]"))
         (total (length recipes))
         (completed 0)
         (errors nil))
    (if (zerop total)
        (message "无配方需要构建")
      (message "开始异步拉取 %d 个包的源码..." total)
      (dolist (recipe recipes)
        (eon-elpa--async-fetch-recipe
         recipe
         (lambda (name err)
           (when err
             (push (cons name err) errors))
           (cl-incf completed)
           (message "拉取进度: %d/%d %s" completed total name)
           (when (= completed total)
             (if errors
                 (message "拉取完成，%d 个失败: %s。继续构建其余包..."
                          (length errors)
                          (string-join (mapcar #'car errors) ", "))
               (message "拉取完成（%d/%d），开始构建..." total total))
             (let ((package-build--inhibit-fetch t))
               (dolist (recipe recipes)
                 (unless (assoc recipe errors)
                   (condition-case err
                       (eon-elpa--build-one recipe)
                     (error
                      (message "构建失败 %s: %s"
                               recipe (error-message-string err)))))))
             (message "构建完成"))))))))

(defun eon-elpa--find-local-dependents (pkg-name)
  "找出本地已安装包中依赖 PKG-NAME 的包名列表。"
  (let ((pkg-sym (intern pkg-name))
        dependents)
    (dolist (entry (package--alist))
      (let ((desc (cadr entry)))
        (when (assq pkg-sym (package-desc-reqs desc))
          (push (symbol-name (car entry)) dependents))))
    (nreverse dependents)))

(defun eon-elpa--find-archive-dependents (pkg-name)
  "找出 archive 中依赖 PKG-NAME 的其他包名列表。"
  (let ((pkg-sym (intern pkg-name))
        dependents)
    (dolist (entry (eon-elpa--read-archive-contents))
      (let ((name (car entry))
            (deps (aref (cdr entry) 1)))
        (when (and (not (eq name pkg-sym))
                   (assq pkg-sym deps))
          (push (symbol-name name) dependents))))
    (nreverse dependents)))

(defun eon-elpa-remove-recipe (recipe-name)
  "移除 RECIPE-NAME 配方及其编译产物，并重建 archive。
移除前检查本地安装状态及依赖关系，有风险时要求确认。"
  (interactive
   (list (completing-read
          "移除包: "
          (directory-files package-build-recipes-dir nil "^[^.]")
          nil t)))
  (let ((local-deps (eon-elpa--find-local-dependents recipe-name))
        (archive-deps (eon-elpa--find-archive-dependents recipe-name))
        (installed (assq (intern recipe-name) (package--alist))))
    (when archive-deps
      (unless (y-or-n-p
               (format "Archive 中以下包依赖 %s: %s\n仍要移除？"
                       recipe-name (string-join archive-deps ", ")))
        (user-error "已取消")))
    (when local-deps
      (unless (y-or-n-p
               (format "本地已安装以下包依赖 %s: %s\n仍要移除？"
                       recipe-name (string-join local-deps ", ")))
        (user-error "已取消")))
    (when installed
      (unless (y-or-n-p (format "%s 当前已安装，仍要移除？" recipe-name))
        (user-error "已取消"))))
  ;; 清理文件
  (delete-file (expand-file-name recipe-name package-build-recipes-dir))
  (dolist (f (file-expand-wildcards
              (expand-file-name (concat recipe-name "-*") package-build-archive-dir)))
    (delete-file f t))
  (let ((dir (expand-file-name recipe-name package-build-working-dir)))
    (when (file-exists-p dir)
      (delete-directory dir t)))
  ;; 重建 archive
  (message "正在异步重建 archive...")
  (eon-elpa-build-all-async)
  (message "%s 配方已移除，archive 正在后台重建" recipe-name))

(eon-elpa--sanitize-package-archives)

(provide 'eon-elpa)
