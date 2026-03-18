;;; -*- lexical-binding: t -*-

;;; rust 配置

(use-package
  rust-mode
  :defer t
  :after (eon-manual-save)
  :hook
  (rust-mode . yas-minor-mode)
  (rust-mode . eon-manual-save-mode))

(use-package
  rustic
  :defer t
  :after (eon-manual-save)
  :custom
  (rustic-analyzer-command
    '("rustup" "run" "stable" "rust-analyzer")))

(provide 'eon-rust)
