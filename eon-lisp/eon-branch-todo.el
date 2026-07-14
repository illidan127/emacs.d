;;; eon-branch-todo.el --- Associate git branches with org TODO items -*- lexical-binding: t; -*-

(require 'org)
(require 'org-id)
(require 'org-agenda)
(require 'magit)

;;; Workspace detection

(defun eon-branch-todo--workspace-root ()
  "Return workspace root directory if the current directory is in an eon workspace.
An eon workspace is identified by the presence of `.eon.yaml' in or above
`default-directory'."
  (when-let ((dir (locate-dominating-file default-directory ".eon.yaml")))
    (expand-file-name dir)))

(defun eon-branch-todo--yaml-file ()
  "Return the .eon.yaml path for the current workspace, or nil."
  (when-let ((root (eon-branch-todo--workspace-root)))
    (expand-file-name ".eon.yaml" root)))

;;; YAML parsing

(defun eon-branch-todo--read-yaml-section (yaml-file)
  "Parse `branch-todo:' section from YAML-FILE.
Returns alist of (branch . uuid)."
  (when (and yaml-file (file-readable-p yaml-file))
    (with-temp-buffer
      (insert-file-contents yaml-file)
      (goto-char (point-min))
      (when (re-search-forward "^branch-todo:[ \t]*$" nil t)
        (forward-line 1)
        (let (result)
          (while (and (not (eobp))
                      (looking-at "^\\([ \t]+\\)\\([^:]+\\):[ \t]*\"?\\([^\"]+\\)\"?[ \t]*$"))
            (let ((branch (string-trim (match-string 2)))
                  (uuid (string-trim (match-string 3))))
              (push (cons branch uuid) result))
            (forward-line 1))
          (nreverse result))))))

(defun eon-branch-todo--write-yaml-section (yaml-file branch uuid)
  "Add or update BRANCH → UUID mapping in YAML-FILE's `branch-todo:' section."
  (let ((content
         (with-temp-buffer
           (insert-file-contents yaml-file)
           (goto-char (point-min))
           (let ((value (format "%s: \"%s\"" branch uuid)))
             (if (re-search-forward "^branch-todo:[ \t]*$" nil t)
                 ;; Section exists — update or append within it
                 (progn
                   (forward-line 1)
                   (let ((sec-body-start (point))
                         (branch-re (format
                                     "^\\([ \t]+\\)%s:[ \t]*\"[^\"]*\"[ \t]*$"
                                     (regexp-quote branch))))
                     (if (re-search-forward branch-re nil t)
                         ;; Replace existing entry
                         (replace-match (concat (match-string 1) value))
                       ;; Append new entry at end of section body
                       (goto-char sec-body-start)
                       (while (and (not (eobp))
                                   (looking-at "^[ \t]+"))
                         (forward-line 1))
                       (insert (format "  %s\n" value)))))
               ;; No section exists — append at end of file
               (goto-char (point-max))
               (unless (bolp) (insert "\n"))
               (insert "branch-todo:\n")
               (insert (format "  %s\n" value))))
           (buffer-string))))
    (with-temp-file yaml-file
      (insert content))))

;;; TODO collection

(defun eon-branch-todo--under-project-or-work-p ()
  "Return non-nil if current heading is under a level-1 heading named 工作 or 项目."
  (let ((under-project nil))
    (save-excursion
      (while (and (org-up-heading-safe)
                  (not under-project))
        (when (= (org-current-level) 1)
          (let ((parent-title (org-get-heading t t t t)))
            (when (or (string-match-p "工作" parent-title)
                      (string-match-p "项目" parent-title))
              (setq under-project t))))))
    under-project))

(defun eon-branch-todo--collect-todos ()
  "Collect non-done TODO items from `org-agenda-files'.
Only includes items under level-1 headings named 工作 or 项目.
Returns alist of (display-string . marker)."
  (let (result)
    (dolist (file org-agenda-files)
      (when (file-exists-p file)
        (with-current-buffer (find-file-noselect file)
          (save-excursion
            (save-restriction
              (widen)
              (org-map-entries
               (lambda ()
                 (let ((todo (org-get-todo-state)))
                   (when todo
                     (let ((done (org-entry-is-done-p))
                           (under (eon-branch-todo--under-project-or-work-p)))
                       (when (and (not done) under)
                         (let* ((title (org-get-heading t t t t))
                                (id (org-entry-get (point) "ID"))
                                (display
                                 (format "%-6s  %s  [%s]%s"
                                         (format "[%s]" todo)
                                         (string-trim (replace-regexp-in-string
                                                       "\\[.*?\\]" "" title))
                                         (file-name-nondirectory file)
                                         (if id "" " ⚠无ID"))))
                           (push (cons display (point-marker)) result)))))))
               nil
               'file))))))
    (sort result
          (lambda (a b)
            (let* ((ma (cdr a)) (mb (cdr b))
                   (buf-a (or (buffer-name (marker-buffer ma)) ""))
                   (buf-b (or (buffer-name (marker-buffer mb)) "")))
              (if (string= buf-a buf-b)
                  (< (marker-position ma) (marker-position mb))
                (string< buf-a buf-b)))))))

;;; Property management

(defun eon-branch-todo--ensure-id ()
  "Ensure the org entry at point has an :ID: property.
Returns the UUID."
  (org-id-get-create))

(defun eon-branch-todo--all-eon-links ()
  "Return list of (workspace . branch) for all EON_LINK* properties at point."
  (save-restriction
    (widen)
    (let ((suffix "")
          result)
      (while-let ((val (save-excursion
                         (org-back-to-heading t)
                         (org-entry-get (point) (concat "EON_LINK" suffix)))))
        (let ((parts (split-string val " " 2)))
          (when (>= (length parts) 2)
            (push (cons (car parts) (cadr parts)) result)))
        (setq suffix (concat suffix "+")))
      (nreverse result))))

(defun eon-branch-todo--add-eon-link (uuid workspace branch)
  "Add an EON_LINK property to the TODO entry at point.
Records WORKSPACE (absolute path) and BRANCH name.
Caller must ensure point is on the correct heading."
  (let ((value (format "%s %s" workspace branch))
        (suffix ""))
    (while (org-entry-get (point) (concat "EON_LINK" suffix))
      (setq suffix (concat suffix "+")))
    (org-entry-put (point) (concat "EON_LINK" suffix) value)))

;;; Branch-to-UUID lookup

(defun eon-branch-todo--uuid-for-branch (yaml-file branch)
  "Return the UUID associated with BRANCH in YAML-FILE, or nil."
  (let ((entries (eon-branch-todo--read-yaml-section yaml-file)))
    (cdr (assoc branch entries))))

;;; Main interactive flow

(defun eon-branch-todo-associate (branch workspace-root)
  "Associate BRANCH in WORKSPACE-ROOT with an org TODO item.
Prompts the user to select an existing TODO, create a new one, or skip."
  (interactive
   (list (magit-get-current-branch)
         (or (eon-branch-todo--workspace-root)
             (user-error "当前不在 eon 工作区内"))))
  (let* ((yaml-file (expand-file-name ".eon.yaml" workspace-root))
         (existing-uuid (eon-branch-todo--uuid-for-branch yaml-file branch))
         (canceled
          (and existing-uuid
               (not (y-or-n-p
                     (format "分支 `%s' 已关联到 TODO (%s)，是否更新关联？"
                             branch existing-uuid))))))
    (if canceled
        (message "已取消")
      (let ((action (completing-read
                     "关联待办项: "
                     '("从待办列表选择" "新建待办项" "跳过")
                     nil t)))
        (cond
         ((string= action "从待办列表选择")
          (let ((todos (eon-branch-todo--collect-todos)))
            (if (not todos)
                (message "org-agenda-files 中没有可关联的待办项")
              (let* ((display (completing-read "选择待办项: "
                                               (mapcar #'car todos)
                                               nil t))
                     (marker (cdr (assoc display todos))))
                (when marker
                  (with-current-buffer (marker-buffer marker)
                    (save-restriction
                      (widen)
                      (goto-char marker)
                      (let ((uuid (eon-branch-todo--ensure-id)))
                        (eon-branch-todo--add-eon-link uuid workspace-root branch)
                        (eon-branch-todo--write-yaml-section
                         yaml-file branch uuid)
                        (message "已关联: %s ↔ %s"
                                 branch
                                 (org-get-heading t t t t))))))
                (when marker (set-marker marker nil))))))
         ((string= action "新建待办项")
          (let* ((file (completing-read "目标文件: " org-agenda-files nil t))
                 (title (read-string "待办项标题: ")))
            (unless (string-empty-p title)
              (with-current-buffer (find-file file)
                (save-restriction
                  (widen)
                  (goto-char (point-min))
                  (unless (org-at-heading-p) (outline-next-heading))
                  (org-insert-heading-respect-content)
                  (insert title)
                  (org-todo "待办"))
                (let ((uuid (org-id-get-create)))
                  (eon-branch-todo--add-eon-link uuid workspace-root branch)
                  (eon-branch-todo--write-yaml-section yaml-file branch uuid)
                  (save-buffer))
                (message "已创建并关联: %s ↔ %s" branch title)))))
         ((string= action "跳过")
          (message "已跳过关联")))))))

(defun eon-branch-todo--after-branch-create (&rest args)
  "After a branch is created and checked out, prompt to associate with TODO.
Installed as `:after' advice on `magit-branch-and-checkout' and
`magit-branch-create'. ARGS are the arguments passed to the advised function:
\(BRANCH START-POINT)."
  (when-let ((ws (eon-branch-todo--workspace-root)))
    (let ((branch (car args)))
      (when (and branch (stringp branch))
        (eon-branch-todo-associate branch ws)))))

;;; Navigation

;;;###autoload
(defun eon-branch-todo-find-todo ()
  "Jump to the org TODO item associated with the current git branch.
Reads the `branch-todo' mapping from the workspace's `.eon.yaml'."
  (interactive)
  (let* ((branch (magit-get-current-branch))
         (yaml-file (eon-branch-todo--yaml-file)))
    (unless branch
      (user-error "当前不在任何 git 分支上"))
    (unless yaml-file
      (user-error "当前不在 eon 工作区内"))
    (let ((uuid (eon-branch-todo--uuid-for-branch yaml-file branch)))
      (unless uuid
        (user-error "分支 `%s' 未关联任何 TODO" branch))
      ;; 临时解除所有 org agenda 文件的窄化状态，确保 ID 搜索不受影响
      (dolist (f org-agenda-files)
        (when-let ((buf (find-buffer-visiting f)))
          (with-current-buffer buf
            (when (buffer-narrowed-p)
              (widen)))))
      (org-id-goto uuid)
      (message "已跳转到: %s" (org-get-heading t t t t)))))

;;;###autoload
(defun eon-branch-todo-find-branch ()
  "From an org TODO entry, switch to an associated git branch.
Prompts if the TODO has multiple EON_LINK entries."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "请在 org-mode 中使用此命令"))
  (let ((links (eon-branch-todo--all-eon-links)))
    (unless links
      (user-error "当前条目没有关联的工作区/分支"))
    (let* ((choice
            (if (= (length links) 1)
                (car links)
              (let* ((candidates
                      (mapcar (lambda (l)
                                (format "%s — %s" (cdr l) (car l)))
                              links))
                     (selected (completing-read "选择关联: " candidates nil t)))
                (nth (cl-position selected candidates :test #'string=) links))))
           (workspace (car choice))
           (branch (cdr choice)))
      (unless (file-directory-p workspace)
        (user-error "工作区目录不存在: %s" workspace))
      (let ((default-directory (file-name-as-directory workspace)))
        (unless (magit-get-current-branch)
          (user-error "%s 不是 git 仓库" workspace))
        (if (string= (magit-get-current-branch) branch)
            (message "已在分支 `%s' 上" branch)
          (magit-checkout branch))))))

(provide 'eon-branch-todo)
;;; eon-branch-todo.el ends here
