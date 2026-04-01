;;; -*- lexical-binding: t -*-


;; 临时放置，后续再解决，防止打开文件弹出提示
(put 'projectile-project-root 'safe-local-variable #'stringp)
(put 'eon-no-auto-format 'safe-local-variable #'booleanp)
(put 'projectile-project-run-cmd 'safe-local-variable #'stringp)


(global-unset-key (kbd "M-c"))

(use-package
  hideshow
  :defer t
  :diminish
  :config
  (push '(js-mode "[[{]" "[]}]" "/[*/]") hs-special-modes-alist)
  (push '(json-mode "[[{]" "[]}]") hs-special-modes-alist)
  :bind (:map hs-minor-mode-map ("M-c" . eon-smart-hs)))

(use-package treesit-fold
  :diminish
  :bind
  (:map treesit-fold-mode-map ("M-c" . eon-smart-hs)))

(defvar eon-treesit-fold-modes (list))

(defun eon-smart-hs (&optional end)
  "自动展开与隐藏"
  (interactive "P")
  (if (member major-mode eon-treesit-fold-modes)
      (treesit-fold-toggle)
    (if (hs-already-hidden-p)
	(hs-show-block end)
      (hs-hide-block end))))


;; 去除已编辑行后多余空格
(use-package ws-butler
  :disabled
  :diminish)

(eon-add-hooks 'prog-mode-hook 'display-line-numbers-mode 'yas-minor-mode)

(use-package aider
  :if (and (boundp 'openai_api_base) (stringp openai_api_base) (> (length openai_api_base) 0)
           (boundp 'openai_api_key) (stringp openai_api_key) (> (length openai_api_key) 0)
           (boundp 'deepseek_api_key) (stringp deepseek_api_key) (> (length deepseek_api_key) 0))
  :config
  (setenv "OPENAI_API_BASE" openai_api_base)
  (setenv "OPENAI_API_KEY" openai_api_key)
  (setenv "DEEPSEEK_API_KEY" deepseek_api_key)
  (setq aider-args '("--model" "deepseek/deepseek-chat" "--no-auto-commits" "--no-gitignore" "--no-show-model-warnings"))
  (global-set-key (kbd "C-c a") 'aider-transient-menu))

(use-package terminal-here
  :config
  (setq terminal-here-mac-terminal-command 'kitty)
  (setq terminal-here-linux-terminal-command 'kitty)
  :bind
  ("C-c t" . terminal-here-project-launch))

(use-package direnv
  :config
  (direnv-mode))

(use-package flyover
  :diminish
  :hook
  (flycheck-mode . flyover-mode))

(use-package agent-shell)

(provide 'eon-program)
