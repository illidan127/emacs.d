;;; -*- lexical-binding: t -*-

(use-package rime
  :config
  ;; (setq rime-posframe-properties
  ;; 	(list :background-color "#333333"
  ;;             :foreground-color "#dcdccc"
  ;;             :font "WenQuanYi Micro Hei Mono-14"
  ;;             :internal-border-width 10))
  (setq rime-show-candidate 'posframe)
  (setq default-input-method "rime")
  (if (eq system-type 'darwin)
      (progn
	(setq rime-emacs-module-header-root "/Applications/Emacs.app/Contents/Resources/include")
	(setq rime-librime-root "~/.nix-profile")))
  (setq rime-share-data-dir "~/.nix-profile/share/rime-data")
  (if (eq system-type 'gnu/linux)
      (setq pgtk-use-im-context-on-new-connection nil)))

(provide 'eon-input-method)
