;; -*- lexical-binding: t; -*-

(require 'ediff)
(require 'cl-lib)

;;; 防止 perspective 与 ediff 兼容问题
(setq ediff-window-setup-function 'ediff-setup-windows-plain)

;; 保存窗口配置的变量
(defvar eon-diff--saved-window-config nil
  "保存的窗口配置，用于ediff退出时恢复")

;; 保存更新定时器
(defvar eon-diff--update-timer nil
  "用于延迟更新ediff的定时器")

(defun eon--find-ediff-control-buffer ()
  "查找当前活跃的ediff控制buffer"
  (cl-find-if
   (lambda (buf)
     (with-current-buffer buf
       (and (boundp 'ediff-buffer-A)
            (boundp 'ediff-buffer-B)
            ediff-buffer-A
            ediff-buffer-B
            ;; 检查是否是我们的*left*和*right* buffers
            (or (and (string= (buffer-name ediff-buffer-A) "*left*")
                     (string= (buffer-name ediff-buffer-B) "*right*"))
                (and (string= (buffer-name ediff-buffer-A) "*right*")
                     (string= (buffer-name ediff-buffer-B) "*left*"))))))
   (buffer-list)))

(defun eon--update-ediff-delayed ()
  "延迟更新ediff对比，避免频繁更新"
  (when eon-diff--update-timer
    (cancel-timer eon-diff--update-timer))
  (setq eon-diff--update-timer
        (run-with-timer 0.5 nil
                        (lambda ()
                          (let ((control-buf (eon--find-ediff-control-buffer)))
                            (when (and control-buf (buffer-live-p control-buf))
                              (with-current-buffer control-buf
                                (ediff-update-diffs))))))))

(defun eon--setup-auto-update-hooks (buffer)
  "为指定buffer设置自动更新钩子"
  (with-current-buffer buffer
    (add-hook 'after-change-functions
              (lambda (beg end len)
                (message "Buffer %s changed, triggering ediff update..." (buffer-name))
                (eon--update-ediff-delayed))
              nil t)
    (message "Auto-update hook added to buffer: %s" (buffer-name))))

(defun eon--cleanup-diff-buffers ()
  "Clean up buffers and restore window configuration after ediff finishes."
  ;; 清理定时器
  (when eon-diff--update-timer
    (cancel-timer eon-diff--update-timer)
    (setq eon-diff--update-timer nil))

  (let ((left-buf (get-buffer "*left*"))
        (right-buf (get-buffer "*right*")))
    ;; 杀死 *left* 和 *right* buffers
    (when left-buf (kill-buffer left-buf))
    (when right-buf (kill-buffer right-buf))
    ;; 恢复之前保存的窗口配置
    (when eon-diff--saved-window-config
      (set-window-configuration eon-diff--saved-window-config)
      (setq eon-diff--saved-window-config nil))
    (message "已恢复窗口布局并清理diff buffers")))

(defun eon--add-ediff-quit-hooks ()
  "添加ediff退出钩子，使用局部钩子避免影响其他ediff会话"
  ;; 移除可能导致frame删除的默认钩子
  (remove-hook 'ediff-quit-hook 'ediff-cleanup-mess)
  ;; 添加我们的清理函数到局部钩子
  (add-hook 'ediff-after-quit-hook-internal #'eon--cleanup-diff-buffers nil t))

(defun eon-diff-empty-buffers ()
  "在当前frame中创建两个空buffer '*left*' 和 '*right*' 并用ediff进行对比。
保存当前窗口布局，ediff退出时自动恢复布局并清理buffers。"
  (interactive)
  ;; 保存当前窗口配置
  (setq eon-diff--saved-window-config (current-window-configuration))

  (let* ((left-buf (get-buffer-create "*left*"))
         (right-buf (get-buffer-create "*right*")))
    ;; 清空buffers内容
    (with-current-buffer left-buf (erase-buffer))
    (with-current-buffer right-buf (erase-buffer))

    ;; 删除其他窗口，只保留当前窗口
    (delete-other-windows)
    ;; 水平分割窗口
    (split-window-right)
    ;; 设置左窗口显示 *left* buffer
    (set-window-buffer (selected-window) left-buf)
    ;; 切换到右窗口并设置显示 *right* buffer
    (other-window 1)
    (set-window-buffer (selected-window) right-buf)
    ;; 回到左窗口
    (other-window 1)

    ;; 配置ediff使用当前frame的窗口，不创建新frame
    (let ((ediff-window-setup-function 'ediff-setup-windows-plain)
          (ediff-split-window-function 'split-window-horizontally)
          (ediff-quit-hook nil))  ; 清空默认的quit钩子

      ;; 启动ediff并添加退出钩子
      (ediff-buffers left-buf right-buf (list #'eon--add-ediff-quit-hooks))

      ;; 为两个buffer设置自动更新钩子
      ;; (eon--setup-auto-update-hooks left-buf)
      ;; (eon--setup-auto-update-hooks right-buf)

      (message "在当前frame中创建了 '*left*' 和 '*right*' buffers进行对比，支持实时更新"))))


(provide 'eon-diff)
