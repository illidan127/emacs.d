;;; -*- lexical-binding: t -*-

(use-package
  pdf-tools
  :defer t
  :init (pdf-loader-install)
  :hook
  (pdf-view-mode . pdf-view-midnight-minor-mode)
  (pdf-view-mode . save-place-mode)
  :bind
  (:map
    pdf-view-mode-map
    ("C-v" . pdf-view-scroll-up-or-next-page)
    ("M-v" . pdf-view-scroll-down-or-previous-page)))

(use-package saveplace-pdf-view
  :after pdf-tools)

(provide 'eon-pdf)
