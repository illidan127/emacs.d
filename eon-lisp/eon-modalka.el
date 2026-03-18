;; -*- lexical-binding: t; -*-

(require 'modalka)
(diminish 'modalka-mode)
(require 'eon-modalka-keys)

;; (add-to-list 'modalka-excluded-modes 'magit-status-mode) ;; 排除 modalka 模式的情形

(defun eon-modalka-enable ()
  "打开 modalka，如果输入法未关闭，会偿试关闭输入法，但不保证成功"
  (interactive)
  (if current-input-method
      (toggle-input-method))
  (if (and (not modalka-mode) (not (member major-mode modalka-excluded-modes)))
      (progn
	(modalka-mode t))))

(defun eon-modalka-disable()
  "关闭 modalka"
  (interactive)
  (if modalka-mode
      (progn
	(modalka-mode -1))))

(defun eon-toggle-input-method ()
  "开启输入法时，退出 modalka"
  (interactive)
  (if current-input-method
      (toggle-input-method)
    (progn
      (eon-modalka-disable)
      (toggle-input-method))))

(define-key global-map (kbd "C-\\") #'eon-toggle-input-method)
(define-key global-map (kbd "<escape>") #'eon-modalka-enable)
(if (boundp 'rime-mode-map)
    ;; rime 下按 esc 时关闭输入法，并进入 modalka
    (define-key rime-mode-map (kbd "<escape>") #'eon-modalka-enable))

(modalka-global-mode 1)

(modalka-define-kbd "a" "C-a")
(modalka-define-kbd "b" #'eon-modalka-b)
(modalka-define-kbd "c" #'eon-modalka-c)
(modalka-define-kbd "d" #'eon-modalka-d)
(modalka-define-kbd "e" #'eon-modalka-e)
(modalka-define-kbd "f" #'eon-modalka-f)
(modalka-define-kbd "g" #'eon-modalka-g)
(define-key modalka-mode-map "h" help-map)
(modalka-define-kbd "i" #'eon-modalka-i)
(modalka-define-kbd "j" #'eon-modalka-j)
(modalka-define-kbd "k" #'eon-modalka-k)
(modalka-define-kbd "l" #'eon-modalka-l)
(modalka-define-kbd "m" #'eon-modalka-m)
(modalka-define-kbd "n" #'eon-modalka-n)
(modalka-define-kbd "o" #'eon-modalka-o)
(modalka-define-kbd "p" #'eon-modalka-p)
(modalka-define-kbd "q" #'eon-modalka-q)
(modalka-define-kbd "r" #'eon-modalka-r)
(modalka-define-kbd "s" #'eon-modalka-s)
(modalka-define-kbd "t" #'eon-modalka-t)
(modalka-define-kbd "u" #'eon-modalka-u)
(modalka-define-kbd "v" "C-v")
(define-key modalka-mode-map "w" eon-window-op-map)
(modalka-define-kbd "x" #'eon-modalka-x)

(modalka-define-kbd "y" "C-y")
(modalka-define-kbd "z" #'eon-modalka-z)

(modalka-define-kbd "SPC" "C-SPC")
(modalka-define-kbd "<return>" #'eon-modalka-return)
(modalka-define-kbd "<backspace>" #'eon-modalka-backspace)

(modalka-define-kbd "/" "C-/")
(modalka-define-kbd "<" "M-<") ;; 至尾部
(modalka-define-kbd ">" "M->") ;; 至头部
(define-key modalka-mode-map "[" #'ignore)
(define-key modalka-mode-map "]" #'ignore)
(define-key modalka-mode-map ";" #'ignore)
(define-key modalka-mode-map "'" #'ignore)
(define-key modalka-mode-map "`" #'ignore)
(modalka-define-kbd "*" "C-*")
(modalka-define-kbd "=" "C-=")

(modalka-define-kbd "\\" "C-\\")

(modalka-define-kbd "1" "C-1")
(modalka-define-kbd "2" "C-2")
(modalka-define-kbd "3" "C-3")
(modalka-define-kbd "4" "C-4")
(modalka-define-kbd "5" "C-5")
(modalka-define-kbd "6" "C-6")
(modalka-define-kbd "7" "C-7")
(modalka-define-kbd "8" "C-8")
(modalka-define-kbd "9" "C-9")
(modalka-define-kbd "0" "C-0")

(provide 'eon-modalka)
