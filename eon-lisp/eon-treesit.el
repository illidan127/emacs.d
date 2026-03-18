;;; -*- lexical-binding: t -*-

(use-package ht
  :ensure t)

(setq treesit-extra-load-path
      (list (expand-file-name "tree-sitter" user-emacs-directory)))

(setq treesit-language-source-alist
      '((bash "https://github.com/tree-sitter/tree-sitter-bash" "v0.23.3")
	(c "https://github.com/tree-sitter/tree-sitter-c" "v0.23.6")
	(cpp "https://github.com/tree-sitter/tree-sitter-cpp" "v0.23.4")
	(css "https://github.com/tree-sitter/tree-sitter-css")
	(cmake "https://github.com/uyha/tree-sitter-cmake" "v0.7.2")
	(c-sharp "https://github.com/tree-sitter/tree-sitter-c-sharp.git" "v0.23.1" "src")
	(dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile")
	(elisp "https://github.com/Wilfred/tree-sitter-elisp")
	(go "https://github.com/tree-sitter/tree-sitter-go" "v0.25.0")
	(gomod "https://github.com/camdencheek/tree-sitter-go-mod.git")
	(html "https://github.com/tree-sitter/tree-sitter-html")
	(java "https://github.com/tree-sitter/tree-sitter-java.git")
	(javascript "https://github.com/tree-sitter/tree-sitter-javascript")
	(json "https://github.com/tree-sitter/tree-sitter-json")
	(lua "https://github.com/tree-sitter-grammars/tree-sitter-lua.git" "v0.3.0")
	(make "https://github.com/alemuller/tree-sitter-make")
	(nix "https://github.com/nix-community/tree-sitter-nix")
	(markdown "https://github.com/MDeiml/tree-sitter-markdown" "v0.4.1" "tree-sitter-markdown/src")
	(ocaml "https://github.com/tree-sitter/tree-sitter-ocaml" "v0.24.2" "grammars/ocaml/src")
	(org "https://github.com/milisims/tree-sitter-org")
	(python "https://github.com/tree-sitter/tree-sitter-python")
	(php "https://github.com/tree-sitter/tree-sitter-php")
	(typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
	(tsx "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")
	(ruby "https://github.com/tree-sitter/tree-sitter-ruby")
	(rust "https://github.com/tree-sitter/tree-sitter-rust" "v0.23.3")
	(sql "https://github.com/m-novikov/tree-sitter-sql")
	(vue "https://github.com/merico-dev/tree-sitter-vue")
	(yaml "https://github.com/ikatyang/tree-sitter-yaml")
	(toml "https://github.com/tree-sitter/tree-sitter-toml")
	(proto "https://github.com/mitchellh/tree-sitter-proto")
	(zig "https://github.com/GrayJack/tree-sitter-zig")))

(defun eon-treesit-enable (language)
  "安装对应的treesit模块"
  (if (assoc language treesit-language-source-alist)
      (if (not (treesit-language-available-p language))
	  (treesit-install-language-grammar language))
    (message "语言 %s 未找到，请检查 `treesit-language-source-alist`"
	     language)))

(defun eon-add-hooks (hook &rest functions)
  "遍历functions列表，将其加入hook中"
  (dolist (f functions)
    ;; (message "add hook %s %s" hook f)
    (add-hook hook f)))

(customize-set-variable 'treesit-font-lock-level 4)

(provide 'eon-treesit)
