;; -*- lexical-binding: t; -*-

;;; 一些工具函数

;; 依赖
(require 'f)

(defun eon-path-in (path path-list)
  "测试PATH是否包含于PATH-LIST中，或者是PATH-LIST中某个路径的前缀
返回 nil 表示PATH不在PATH-LIST中，也不是其中任何路径的前缀。
返回 PATH 表示PATH在PATH-LIST中。
返回路径列表，包含所有前缀是PATH的路径。"
  (let* (hit
	 (result (-filter (lambda (item)
			    (if (f-same-p path item)
				(setq hit path))
			    (f-ancestor-of-p path item)) path-list)))
    (or hit result)))


(defun eon-path-list-contains (path-list path)
  "测试PATH-LIST是否包含PATH，或者PATH-LIST中某个路径是PATH的前缀
返回 nil 表示PATH不在PATH-LIST中，PATH-LIST中也不包含PATH的前缀。
返回 路径PATH 表示PATH在PATH-LIST中。
返回路径列表，包含PATH-LIST中所有PATH的前缀。"
  (let* (hit
	 (result (-filter (lambda (item)
			    (if (f-same-p item path)
				(setq hit path))
			    (f-ancestor-of-p item path)) path-list)))
    (or hit result)))



(defun eon-lib-number-to-binary (n &optional width)
  "将数字N转换为二进制字符串，可选参数WIDTH指定最小宽度（不足补零）"
  (if (zerop n)
      (if width
          (make-string width ?0)
        "0")
    (let ((bits '())
          (unsigned (abs n)))
      (while (> unsigned 0)
        (push (if (= 1 (logand unsigned 1)) ?1 ?0) bits)
        (setq unsigned (lsh unsigned -1)))
      (when (minusp n)
        (push ?- bits))
      (let ((binary (concat bits)))
        (if (and width (> width (length binary)))
            (concat (make-string (- width (length binary)) ?0) binary)
          binary)))))


(defun eon-lib-count-char (char string)
  (cl-loop for c across string
	   when (char-equal char c)
	   count 1))


(defun eon-get-location ()
  "生成一个字符串，包含当前buffer的文件名和point所在的行号。
格式为：filename:line-number，并将结果放入kill-ring。"
  (interactive)
  (let* ((filename (or (buffer-file-name) (buffer-name)))
         (line-number (line-number-at-pos (point)))
         (result (format "%s:%d" filename line-number)))
    (kill-new result)
    (message "Copied: %s" result)
    result))


(defmacro eon-first-success (&rest forms)
  "依次尝试执行 FORMS 中的表达式，若某个表达式成功返回该值，否则继续下一个。若都失败返回 nil。"
  `(catch 'success
     ,@(mapcar (lambda (form)
		 `(catch 'break
                    (condition-case nil
			,form
		      (error (throw 'break nil)))
		    (throw 'success nil)))
	       forms)
     nil))


(provide 'eon-lib)
