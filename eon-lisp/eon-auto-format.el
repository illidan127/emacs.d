;;; -*- lexical-binding: t -*-

(use-package format-all
  :config
  ;; 必须在 :config（而非 :init）中设置，因为 language-id（作为
  ;; format-all 的依赖加载）使用 defconst，如果在 language-id.el
  ;; 加载之前设置，会被覆盖。
  (setq language-id--definitions (cons '("Protocol Buffer" protobuf-ts-mode) language-id--definitions))
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
  (define-format-all-formatter buf-format
    (:executable "buf")
    (:install "do nothing")
    (:languages "Protocol Buffer")
    (:features region)
    (:format
     (format-all--buffer-thunk
      (lambda (input)
        (let* ((safe-dir (or (and (buffer-file-name)
                                  (file-name-directory (buffer-file-name)))
                             "/tmp"))
               (temporary-file-directory safe-dir)
               (default-directory safe-dir)
               (tmpfile (make-temp-file "format-all-buf-" nil ".proto"))
               (errfile (make-temp-file "format-all-err-")))
          (unwind-protect
              (progn
                (with-temp-file tmpfile
                  (insert input))
                (let* ((status (call-process executable nil (list t errfile) nil
                                            "format" tmpfile))
                       (err (with-temp-buffer
                              (insert-file-contents errfile)
                              (buffer-string))))
                  (list (not (eq status 0)) err)))
            (ignore-errors (delete-file tmpfile))
            (ignore-errors (delete-file errfile))))))))
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
