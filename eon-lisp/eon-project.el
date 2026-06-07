;;; -*- lexical-binding: t -*-

;;; 工程配置相关

(require 'cl-lib)
(require 'seq)

(declare-function agent-shell-buffers "agent-shell")
(declare-function agent-shell-status "agent-shell")
(declare-function agent-shell--permission-pending-p "agent-shell")
(declare-function shell-maker-busy "shell-maker")
(declare-function eon-workspace--known-projects "eon-workspace")

(defun eon-project--git-repo-p (dir)
  (file-exists-p (expand-file-name ".git" dir)))

(defun eon-project--git-repos-in-project (root)
  "收集 ROOT 及其直接子目录中的 Git 仓库路径。"
  (let ((root (directory-file-name (expand-file-name root)))
        repos)
    (when (eon-project--git-repo-p root)
      (push root repos))
    (dolist (dir (directory-files root t "^[^.].*" t))
      (when (and (file-directory-p dir)
                 (eon-project--git-repo-p dir))
        (push dir repos)))
    repos))

(defun eon-reset-magit-repository-list ()
  "根据 eon-workspace 已知项目列表，重置 `magit-repository-directories'。"
  (interactive)
  (require 'eon-workspace)
  (let* ((projects (eon-workspace--known-projects))
         (repos (cl-delete-duplicates
                 (apply #'append
                        (mapcar #'eon-project--git-repos-in-project projects))
                 :test #'string=)))
    (setq magit-repository-directories
          (if repos
              (mapcar (lambda (dir) (cons dir 0)) repos)
            nil))))


(defun eon-magit-status-wrapper ()
  "根据情况执行`magit-status'或`magit-repolist-status'"
  (interactive)
  (eon-reset-magit-repository-list)
  (if magit-repository-directories
      (call-interactively #'magit-list-repositories)
    (call-interactively #'magit-status)))


;;;; agent-shell

(defun eon-project--agent-shell-buffers ()
  "返回全部 agent-shell buffer；优先 `agent-shell-buffers'。"
  (if (fboundp 'agent-shell-buffers)
      (agent-shell-buffers)
    (seq-filter (lambda (buf)
                  (with-current-buffer buf
                    (derived-mode-p 'agent-shell-mode)))
                (buffer-list))))

(defun eon-project--agent-shell-permission-pending-p ()
  "当前 buffer 是否有待处理的 permission 请求。"
  (cond
   ((fboundp 'agent-shell--permission-pending-p)
    (agent-shell--permission-pending-p))
   ((and (boundp 'agent-shell--state)
         (map-elt agent-shell--state :tool-calls))
    (seq-some (lambda (entry)
                (map-elt (cdr entry) :permission-request-id))
              (map-elt agent-shell--state :tool-calls)))
   (t nil)))

(defun eon-project--agent-shell-buffer-blocked-p (buf)
  "BUF 是否在等待用户授权（与 `agent-shell-status' 的 `blocked' 等价）。"
  (with-current-buffer buf
    (unless (derived-mode-p 'agent-shell-mode)
      (cl-return nil))
    (cond
     ((fboundp 'agent-shell-status)
      (eq 'blocked (agent-shell-status :shell-buffer buf)))
     (t
      (and (eon-project--agent-shell-permission-pending-p)
           (or (not (fboundp 'shell-maker-busy))
                (shell-maker-busy)))))))

(defun eon-project--first-blocked-agent-shell-buffer ()
  "返回第一个等待授权的 agent-shell buffer；无则 nil。"
  (seq-find #'eon-project--agent-shell-buffer-blocked-p
            (eon-project--agent-shell-buffers)))

(defun eon-project--switch-to-buffer-in-any-frame (buf)
  "在任意 frame 中显示 BUF；若已在某窗口显示则切到该 frame/window。"
  (let ((win (get-buffer-window buf 'visible)))
    (if win
        (progn
          (select-frame-set-input-focus (window-frame win))
          (select-window win))
      (switch-to-buffer buf))))

;;;###autoload
(defun eon-project-switch-to-blocked-agent-shell ()
  "切换到第一个等待用户授权（permission）的 agent-shell buffer。
遍历当前 Emacs 中全部 agent-shell 实例。
若无等待授权的 shell，则报错。"
  (interactive)
  (require 'agent-shell)
  (if-let ((buf (eon-project--first-blocked-agent-shell-buffer)))
      (progn
        (eon-project--switch-to-buffer-in-any-frame buf)
        (message "已切换到等待授权的 agent-shell: %s" (buffer-name buf)))
    (user-error "没有等待用户授权的 agent-shell")))


(use-package eon-workspace
  :demand t
  :bind (("<f8>" . eon-workspace-create)
         ("<f9>" . eon-project-switch-to-blocked-agent-shell)
         ([remap switch-to-buffer] . eon-workspace-switch-to-buffer))
  :config
  (eon-workspace-buffer-isolation-mode 1)
  (define-key ivy-mode-map [remap switch-to-buffer]
              #'eon-workspace-switch-to-buffer))


(provide 'eon-project)
