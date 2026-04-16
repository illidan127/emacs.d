;;; -*- lexical-binding: t -*-

(defcustom eon-npm-path "npm"
  "npm工具路径或命令行，如果不在$PATH中，需要指定绝对路径"
  :group 'eon
  :type 'string)

(defcustom eon-tex2svg-path "tex2svg"
  "tex2svg工具路径，如果不在PATH中，需要写绝对路径"
  :group 'eon
  :type 'string)

(defcustom eon-plantuml-output-prefix ""
  "plantuml图形路径前缀"
  :group 'eon
  :type 'string
  :local t)

(defcustom eon-dot-output-prefix ""
  "dot图形路径前缀"
  :group 'eon
  :type 'string
  :local t)

(defun eon-exclude-project ()
  "跳过部分条目"
  (let ((level (org-current-level)))
    (save-excursion
      (while (> (org-current-level) 1)
	(org-up-heading-safe))
      (if (or (string= (org-get-heading t t t) "abc"))
	  (org-end-of-subtree t)
	nil))))

(defun eon-org-archive-archivable()
  "归档过期条目"
  (interactive)
  (org-ql-select org-agenda-files `(and (or (parent (heading "工作")) (parent (heading "项目"))) (level 2) (closed :to ,(ts-format (ts-adjust 'day -30 (ts-now)))))
    :action 'org-archive-subtree))

(defun eon--reorder-todos ()
  "重排"
  (let ((element (org-element-at-point)))
    (if (and (eq (org-element-type element) 'headline)
	     (= 1 (org-element-property :level element)))
	(progn
	  (org-sort-entries t ?o)
	  (org-fold-hide-subtree)
	  (org-fold-show-children)))))

(defun eon-reorder-all-todos ()
  "重新排列 Agenda 文件中的所有待办条目。"
  (interactive)
  (dolist (agenda (org-buffer-list 'agenda))
    (with-current-buffer agenda
      (org-map-entries 'eon--reorder-todos))))

(defun eon-reorder-current-todos ()
  "某条待办变更后，重排其所在待办序列"
  (interactive)
  (org-up-heading-safe)
  (org-sort-entries t ?o)
  (org-fold-hide-subtree)
  (org-fold-show-children))

(defun eon-org-last-friday ()
  "Calculate and return last Friday's date as a string in YYYY-MM-DD format."
  (let* ((today (current-time))
         (today-day (string-to-number (format-time-string "%w" today))) ; 0-6 (Sun-Sat)
         (days-since-friday (mod (- today-day 5) 7)) ; Friday is 5
         (last-friday (time-subtract today (days-to-time (+ days-since-friday 7)))))
    (format-time-string "%Y-%m-%d" last-friday)))

(defun eon-tasks-current-day-todo ()
  "定位到当前日所在的节点，不存在将插入"
  (interactive)
  (let ((result nil))
    (with-current-buffer (current-buffer)
      (org-map-entries #'(lambda () (let ((current-heading (org-heading-components)))
				 (if (eon-current-day-todo-heading-p current-heading)
				     (setq result (point)))))
		       "LEVEL=1")
      (if result
	  (goto-char result)
	(goto-char (point-min))
	(org-next-visible-heading 1)
	(org-insert-heading nil nil 1)
	(insert (format-time-string "%Y 年 %m 月 %d 日"))))))

(defun eon-open-agenda-file ()
  (interactive)
  (find-file (car org-agenda-files)))

(defun eon-org-agenda-goto-and-narrow ()
  "在 org-agenda 中跳转到待办条目并窄化到该子树"
  (interactive)
  (org-agenda-switch-to)
  (org-narrow-to-subtree))

(defun eon-reset-org-mode-prettify-symbols-alist ()
  (interactive)
  (setq prettify-symbols-alist
	`(("#+begin_src plantuml" . ,(eon-string-to-symbol-list "[Plantuml代码]"))
	  ("#+begin_src bash" . ,(eon-string-to-symbol-list "[Bash代码]"))
	  ("#+begin_src C++" . ,(eon-string-to-symbol-list "[C++代码]"))
	  ("#+end_src" . (?结 (Br . Bl) ?束))
	  ("#+RESULTS:" . ,(eon-string-to-symbol-list "结果："))
	  ("进行中" . ,(eon-string-to-symbol-list "[进行中]"))
	  ("开发中" . ,(eon-string-to-symbol-list "[开发中]"))
	  ("待发布" . ,(eon-string-to-symbol-list "[待发布]"))
	  ("发布中" . ,(eon-string-to-symbol-list "[发布中]"))
	  ("待办" . ,(eon-string-to-symbol-list "[待办]"))
	  ("暂缓" . ,(eon-string-to-symbol-list "[暂缓]"))
	  ("完成" . ,(eon-string-to-symbol-list "[完成]"))
	  ("完成于:" . ,(eon-string-to-symbol-list "完成于:"))
	  ("放弃" . ,(eon-string-to-symbol-list "[放弃]"))
	  ("[#A]" . ,(eon-string-to-symbol-list "Ⓐ"))
	  ("[#B]" . ,(eon-string-to-symbol-list "Ⓑ"))
	  ("[#C]" . ,(eon-string-to-symbol-list "Ⓒ")))))


(defun eon-counsel-outline ()
  "对日程文件使用定制的outline函数，其他org文件使用原始的counsel-outline"
  (interactive)
  (if (member (buffer-file-name) org-agenda-files)
      (call-interactively #'eon-tasks-org-counsel-outline)
    (call-interactively #'counsel-outline)))

(defvar eon-agenda-query-regexp nil)

(defcustom eon-auto-tags nil
  "插入标题时自动添加的 Org 属性名列表。
非空时，对每个元素调用 `org-set-property'，属性名为该元素（字符串或符号），值为空字符串。"
  :group 'eon
  :type '(repeat (choice string symbol)))

(defun eon-org-insert-heading-add-properties-from-auto-tags ()
  "当 `eon-auto-tags' 为非空列表时，为当前标题按列表项添加空属性值。"
  (when (and eon-auto-tags
             (listp eon-auto-tags))
    (dolist (prop eon-auto-tags)
      (when prop
        (org-set-property (if (stringp prop) prop (symbol-name prop)) "-")))))

(defun eon-tasks-counsel-org-goto-action (x)
  "定位到某个工作计划表，并更新其内容"
  (org-goto-marker-or-bmk (cdr x))
  (org-fold-show-subtree)
  (next-line)
  (back-to-indentation)
  (org-ctrl-c-ctrl-c))

(defun eon-tasks-org-counsel-outline ()
  "效果同org模式下counsel-outline，但增加了过滤，只显示满足
EON-AGENDA-QUERY-REGEXP的记录"
  (interactive)
  (let ((settings (cdr (assq major-mode counsel-outline-settings))))
    (ivy-read "Outline: " (counsel-outline-candidates settings)
              :action 'eon-tasks-counsel-org-goto-action
              :history (or (plist-get settings :history)
                           'counsel-outline-history)
              :preselect (max (1- counsel-outline--preselect) 0)
	      :predicate (lambda (item) (or (not eon-agenda-query-regexp)
				       (string-match-p eon-agenda-query-regexp (car item))))
              :caller (or (plist-get settings :caller)
                          'counsel-outline))))

(use-package uuid)

(use-package org
  :ensure nil
  :init
  (put 'org-ql-ask-unsafe-queries 'safe-local-variable #'booleanp)
  (put 'eon-agenda-query-regexp 'safe-local-variable #'stringp)
  (put 'auto-revert-mode 'safe-local-variable #'booleanp)
  (put 'eon-plantuml-output-prefix 'safe-local-variable #'stringp)
  (put 'eon-dot-output-prefix 'safe-local-variable #'stringp)
  (put 'eon-auto-tags 'safe-local-variable
       (lambda (val)
         (or (null val)
             (and (listp val)
                  (let ((ok t))
                    (dolist (x val ok)
                      (unless (or (stringp x) (symbolp x))
                        (setq ok nil))))))))
  ;; org文件夹路径
  (eon-treesit-enable 'org)
  (eon-set-org-directory)
  ;; (setq org-closed-string "完成于:")
  ;; (setq org-element-closed-keyword "完成于:") ;; 非常重要，org根据此关键字识别 :closed 属性
  :config
  ;; 杂项配置
  (setq org-special-ctrl-a/e 't)
  (setq org-startup-indented t)
  (setq org-ellipsis " ▼ ")
  (setq org-hide-leading-stars t)
  (setq truncate-lines nil)
  ;; 日程相关配置
  (setq calendar-week-start-day 1)
  (setq org-agenda-files (list (file-name-concat org-directory "tasks.org")))
  (setq org-agenda-todo-ignore-deadlines 'far)
  (setq org-agenda-todo-ignore-scheduled 'future)
  (setq org-use-tag-inheritance nil)
  ;; (setq org-log-into-drawer t) ;; LOGBOOK

  ;; 日程视图排除项目
  (setq org-agenda-skip-function-global 'eon-exclude-project)

  ;; org-latex-preview时设置背景透明
  (plist-put org-format-latex-options :background "Transparent")
  (setq org-todo-keywords
	'((sequence "进行中(j)" "开发中(k)" "发布中(f)" "待发布(d)" "待办(D)" "暂缓(z)" "|" "完成(w)" "放弃(g)")))
  (setq org-todo-keyword-faces
	'(("待办" . "red")
	  ("进行中" . (:foreground "#51cf66" :weight bold))
	  ("开发中" . (:foreground "#51cf66" :weight bold))
	  ("待发布" . (:foreground "#ffd43b" :weight bold))
	  ("发布中" . (:foreground "#ff922b" :weight bold))
	  ("完成" . "green")
	  ("暂缓" . "blue")
	  ("放弃" . "grey")))
  (setq org-log-done 'time)
  (setq org-time-stamp-formats (cons "%Y-%m-%d" "%Y-%m-%d %H:%M"))
  (setq org-capture-templates (list))
  ;; (setq org-log-done-with-time nil) ;; 记录完成标签时，是否记录时间戳
  (add-hook 'org-insert-heading-hook #'eon-org-insert-heading-add-properties-from-auto-tags 'append)
  (add-to-list
   'org-capture-templates
   `("w" "工作待办" entry (id "60d5b5e0-b803-442f-bc6d-1dc55148802c")
     "* 待办 %? %x" :prepend t :before-finalize org-id-get-create))

  (add-to-list
   'org-capture-templates
   `("x" "项目待办" entry (id "19b7a7a2-19ae-4abf-8092-ef4595217b96")
     "* 待办 %? %x" :prepend t :before-finalize org-id-get-create))

  (add-to-list
   'org-capture-templates
   `("k" "事业待办" entry (id "4f9c72dd-75a0-4fc0-83bd-ef74693132d7")
     "* 待办 %? %x" :prepend t :before-finalize org-id-get-create))

  ;; 优先级设置
  (setq
   org-default-priority ?B
   org-highest-priority ?A
   org-lowest-priority ?C
   org-priority-faces '((?A . (:foreground "yellow" :weight bold))
			(?B . (:foreground "blue"))
			(?C . (:foreground "blue"))))

  (setq org-agenda-prefix-format '((agenda . " %i %-12:c%?-12t% s") (todo . " %i %-12:c %(car (org-get-outline-path)) ")
				   (tags . " %i %-12:c") (search . " %i %-12:c")))

  ;; 嵌入文件支持
  (setq org-src-preserve-indentation t)
  (setq org-src-ask-before-returning-to-edit-buffer nil)
  (setq org-edit-src-auto-save-idle-delay 0.1)
  (setq org-confirm-babel-evaluate nil)
  (setq org-format-latex-options
	(plist-put org-format-latex-options :scale 1.6))
  (setq org-preview-latex-default-process 'dvisvgm) ;; 用svg图片做行内latex图片，否则高分屏下图像很小

  ;; (modify-syntax-entry ?+ "(+" org-mode-syntax-table)

  (org-babel-do-load-languages
   'org-babel-load-languages
   '((awk, t) (C, t) (calc, t) (shell, t) (clojure, t) (comint, t) (css, t)
     (ditaa, t) (eshell, t) (forth, t) (gnuplot, t)
     (screen, t) (sed, t) (dot, t) (haskell, t) (java, t) (julia, t) (latex, t)
     (lisp, t) (lua, t) (makefile, t) (matlab, t) (js, t) (ocaml, t)
     (octave, t) (org, t) (perl, t) (plantuml, t) (processing, t) (python, t) (R, t)
     (ruby, t) (sass, t) (scheme, t) (sql, t) (sqlite, t)))
  (setq org-plantuml-exec-mode 'plantuml)

  :bind
  ("C-c o a" . org-agenda)
  ("C-c o o" . org-capture)
  :hook
  ;; 添加或修改待办事项后，保存所有org文件
  (org-capture-after-finalize . org-save-all-org-buffers)
  (org-agenda-finalize . org-save-all-org-buffers)
  ;; 待办事项有修改时，重新排序
  (org-capture-after-finalize . eon-reorder-all-todos)
  (org-after-todo-state-change . eon-reorder-current-todos)
  ;; 启动yasnippet
  (org-mode . yas-minor-mode)
  ;; 更新代码块后，重新显示图片
  (org-babel-after-execute . org-redisplay-inline-images)
  ;; 设置一些符号
  (org-mode . eon-reset-org-mode-prettify-symbols-alist)
  (org-mode . prettify-symbols-mode))


(use-package
  org-latex-impatient
  :defer t
  :disabled
  :after (org)
  :if (executable-find eon-tex2svg-path)
  :init (setq org-latex-impatient-tex2svg-bin eon-tex2svg-path)
  :config
  (setq org-latex-impatient-scale 1.0)
  (setq org-latex-impatient-delay 0.5)
  (setq org-latex-impatient-posframe-position 'point)
  (setq org-latex-impatient-posframe-position-handler
	#'posframe-poshandler-point-window-center)
  :hook (org-mode . org-latex-impatient-mode))

(use-package
  ;;; latex公式行内图片
  org-fragtog
  :hook (org-mode . org-fragtog-mode))

(use-package epa-file
  :ensure nil
  :config
  (setq epa-pinentry-mode 'loopback)
  (setq epa-file-select-keys 1)
  ;; 某些org-mode版本与gnupg程序配合有问题
  ;; gnupg2.4版本以上标准输出有变化，导致org-mode中等待特定输出的函数无限等待
  ;; 因此需要将`epg-wait-for-status`设置为ignore
  ;; org-mode最新版本似乎已适配了这个问题，设置为ignore反而会导致gpg文件加密出现问题
  ;; (fset 'epg-wait-for-status 'ignore)
  (setq epa-file-cache-passphrase-for-symmetric-encryption t))

(use-package pinentry)

(use-package org-ql
  :config
  (require 'org-ql-search)
  (require 'org-ql-find)
  (org-ql-defpred eon-org-closed-from (begin)
    "来自org-ql中的closed谓词"
    :body
    (let ((from (ts-parse-fill 'begin begin)))
      (org-ql--predicate-ts :from from :regexp org-closed-time-regexp :match-group 1
                            :limit (line-end-position 2))))
  )

(defcustom eon-dot-default-options
  '("-T%s" ;; 输出文件
    "-Gbgcolor=transparent" ;; 全局背景色
    "-Gfontcolor=white" ;; 全局字体色
    "-Ncolor=white" ;; 默认节点边框颜色
    "-Nfontcolor=white" ;; 默认节点字体色
    "-Ecolor=white" ;; 默认边色
    "-Efontcolor=white" ;; 默认边上字体色
    )
  "默认的dot图形选项，主要用于行内图形预览。
可以在代码块中额外用 :cmdline 指定。"
  :group 'eon
  :type (list 'string))

(defun org-babel-execute:dot (body params)
  "功能同原始的org-babel-execute:dot
差别：以uuid自动生成文件名，默认为svg图
自动输出到特定目录下，不污染org顶层目录"
  (let* ((out-file (cdr (or (assq :file params)
			    (cons :file (f-join eon-dot-output-prefix (concat (uuid-string) ".svg")))
			    (error "You need to specify a :file parameter"))))
	 (cmdline (or (cdr (assq :cmdline params))
		      (format (string-join eon-dot-default-options " ") (file-name-extension out-file))))
	 (cmd (or (cdr (assq :cmd params)) "dot"))
	 (coding-system-for-read 'utf-8) ;use utf-8 with sub-processes
	 (coding-system-for-write 'utf-8)
	 (in-file (org-babel-temp-file "dot-")))
    (with-temp-file in-file
      (insert (org-babel-expand-body:dot body params)))
    (org-babel-eval
     (concat cmd
	     " " (org-babel-process-file-name in-file)
	     " " cmdline
	     " -o " (org-babel-process-file-name out-file)) "")
    out-file)) ;; signal that output has already been written to file

(defun org-babel-execute:plantuml (body params)
  "功能同原始的org-babel-execute:plantuml
差别：以uuid自动生成文件名，默认为svg图
自动输出到特定目录下，不污染org顶层目录"
  (let* ((do-export (member "file" (cdr (assq :result-params params))))
         (out-file (if do-export
                       (or (cdr (assq :file params))
                           (f-join eon-plantuml-output-prefix (concat (uuid-string) ".svg")))
		     (org-babel-temp-file "plantuml-" ".txt")))
	 (cmdline (cdr (assq :cmdline params)))
	 (in-file (org-babel-temp-file "plantuml-"))
	 (java (or (cdr (assq :java params)) ""))
	 (executable (cond ((eq org-plantuml-exec-mode 'plantuml) org-plantuml-executable-path)
			   (t "java")))
	 (executable-args (cond ((eq org-plantuml-exec-mode 'plantuml) org-plantuml-args)
				((string= "" org-plantuml-jar-path)
				 (error "`org-plantuml-jar-path' is not set"))
				((not (file-exists-p org-plantuml-jar-path))
				 (error "Could not find plantuml.jar at %s" org-plantuml-jar-path))
				(t `(,java
				     "-jar"
				     ,(shell-quote-argument (expand-file-name org-plantuml-jar-path))
                                     ,@org-plantuml-args))))
	 (full-body (org-babel-plantuml-make-body body params))
	 (cmd (mapconcat #'identity
			 (append
			  (list executable)
			  executable-args
			  (pcase (file-name-extension out-file)
			    ("png" '("-tpng"))
			    ("svg" '("-tsvg"))
			    ("eps" '("-teps"))
			    ("pdf" '("-tpdf"))
			    ("tex" '("-tlatex"))
                            ("tikz" '("-tlatex:nopreamble"))
			    ("vdx" '("-tvdx"))
			    ("xmi" '("-txmi"))
			    ("scxml" '("-tscxml"))
			    ("html" '("-thtml"))
			    ("txt" '("-ttxt"))
			    ("utxt" '("-utxt")))
			  (list
			   "-p"
			   cmdline
			   "<"
			   (org-babel-process-file-name in-file)
			   ">"
			   (org-babel-process-file-name out-file)))
			 " ")))
    (with-temp-file in-file (insert full-body))
    (message "%s" cmd) (org-babel-eval cmd "")
    (if (and (string= (file-name-extension out-file) "svg")
             org-babel-plantuml-svg-text-to-path)
        (org-babel-eval (format "inkscape %s -T -l %s" out-file out-file) ""))
    (unless do-export (with-temp-buffer
                        (insert-file-contents out-file)
                        (buffer-substring-no-properties
                         (point-min) (point-max))))
    out-file))


(use-package valign
  ;; valign可以在表格中有数学公式图片时，保持列对齐
  :after (org)
  :hook (org-mode . valign-mode))


(provide 'eon-org)
