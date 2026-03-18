;;; -*- lexical-binding: t -*-

(use-package format-all
  :init
  (unless (boundp 'language-id--definitions)
    (setq language-id--definitions nil))
  (setq language-id--definitions (cons '("Protocol Buffer" protobuf-ts-mode) language-id--definitions))
  :config
  (setq eon-go-formatter (f-join user-emacs-directory "eon-lisp" "goimports-gci.sh"))
  (define-format-all-formatter goimports-gci
    (:executable eon-go-formatter)
    (:install "do nothing")
    (:languages "Go")
    (:features)
    (:format (format-all--buffer-easy executable)))
  (define-format-all-formatter dockerfmt
    (:executable "dockerfmt")
    (:install "do nothing")
    (:languages "Dockerfile")
    (:features)
    (:format (format-all--buffer-easy executable)))
  (setq-default format-all-formatters '(("_Nginx" (nginxfmt))
					("Nix" nixpkgs-fmt)
					("YAML" prettierd)
					("Go" goimports)
					("Python" yapf)
					("Emacs Lisp" emacs-lisp)
					("Protocol Buffer" clang-format)
					("Clojure" (cljfmt "fix"))
					("Shell" shfmt)
					("TSX" prettierd)
					("JavaScript" deno)
					("C++" clang-format)
					("Dockerfile" dockerfmt)
					("C" clang-format)
					("Lua" stylua)
					("CMake" cmake-format)))
  )

(provide 'eon-auto-format)
