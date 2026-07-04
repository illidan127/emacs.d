;;; -*- lexical-binding: t -*-


;; 临时放置，后续再解决，防止打开文件弹出提示
(put 'eon-no-auto-format 'safe-local-variable #'booleanp)

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
  :disabled
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

(defun eon--display-agent-shell-buffer (buf)
  "显示 BUF 并将焦点切到对应窗口。
若 BUF 已在某窗口显示，直接选中该窗口；否则新开窗口显示，不占用当前窗口。"
  (let ((win (get-buffer-window buf 'visible)))
    (if win
        (progn
          (select-frame-set-input-focus (window-frame win))
          (select-window win))
      (pop-to-buffer buf))))

(use-package agent-shell
  :config
  (setq agent-shell-cursor-acp-command `("cursor-agent" "--api-key" ,eon-cursor-api-key "acp"))
  (setq agent-shell-anthropic-claude-environment
        (apply #'agent-shell-make-environment-variables claude-env))
  (setq agent-shell-goose-environment
	(apply #'agent-shell-make-environment-variables goose-env))
  (setq agent-shell-goose-authentication
        (agent-shell-make-goose-authentication :none t))
  )

(use-package ghostel
  :defer t
  :commands (ghostel ghostel-project ghostel-other ghostel-next ghostel-previous
               ghostel-list-buffers)
  :init
  (setq ghostel-module-auto-install 'download)
  :config
  (defun eon-ghostel-escape-from-char ()
    "Exit ghostel char mode, enter emacs mode, and activate modalka."
    (interactive)
    (ghostel-emacs-mode)
    ;; 绕过 modalka-excluded-modes 检查，直接激活
    (modalka-mode t))
  (define-key ghostel-char-mode-map (kbd "<escape>") #'eon-ghostel-escape-from-char)
  (defun eon-modalka-ghostel-to-char ()
    "Disable modalka and enter ghostel char mode."
    (interactive)
    (eon-modalka-disable)
    (ghostel-char-mode))

  ;; ghostel buffer 中禁止 modalka 自动激活（通过 ESC 手动激活）
  (add-to-list 'modalka-excluded-modes 'ghostel-mode)

  ;; 默认进入 char 模式
  (add-hook 'ghostel-mode-hook #'ghostel-char-mode)

  ;; 禁用 semi-char / copy / line 模式
  (advice-add 'ghostel-semi-char-mode :override #'ghostel-char-mode)
  (advice-add 'ghostel-copy-mode      :override #'ghostel-emacs-mode)
  (advice-add 'ghostel-line-mode      :override #'ignore)

  ;; char 模式下 M-RET / C-M-m 也走 emacs 模式（与 ESC 一致）
  (define-key ghostel-char-mode-map (kbd "M-RET")      #'ghostel-emacs-mode)
  (define-key ghostel-char-mode-map (kbd "M-<return>") #'ghostel-emacs-mode)
  (define-key ghostel-char-mode-map (kbd "C-M-m")      #'ghostel-emacs-mode))

(provide 'eon-program)

