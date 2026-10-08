;;; -*- lexical-binding: t -*-

;; 拉丁/等宽部分走 default 与 fixed-pitch。
(set-face-attribute 'default nil :font (font-spec :family "LXGW WenKai Mono"))
(set-face-attribute 'fixed-pitch nil :font (font-spec :family "LXGW WenKai Mono"))

;; CJK 字符由 fontset 解析，而不是上面的 default face，须显式指定。
;; 否则 macOS(NS/mac-ct) 会按默认 fontset 的 :lang/registry 回退到系统
;; PingFang SC。`han' 覆盖汉字，`cjk-misc' 覆盖中文全角标点（，。、：；
;; 等），`bopomofo' 覆盖注音符号。t 表示对所有现有及新建 frame 生效。
(dolist (script '(han cjk-misc bopomofo))
  (set-fontset-font t script (font-spec :family "LXGW WenKai Mono")))

(provide 'eon-font)
