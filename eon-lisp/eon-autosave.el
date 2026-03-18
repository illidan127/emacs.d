;;; -*- lexical-binding: t -*-

;;; 自动保存功能

(use-package super-save
  :diminish
  :init
  (setq auto-save-default nil) ;; 禁用自带的自动保存
  (setq make-backup-files nil) ;; 不备份
  (setq create-lockfiles nil) ;; 不锁文件
  :config
  (setq super-save-auto-save-when-idle t)
  (setq super-save-idle-duration 0.8)
  (setq super-save-max-buffer-size 100000000000)
  (super-save-mode))

(provide 'eon-autosave)
