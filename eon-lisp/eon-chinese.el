;; -*- lexical-binding: t; -*-

;;; 中文相关的一些配置

;; 数字大小写转换
(setq eon-chinese-numbers
      '((?壹 ?一)
	(?贰 ?二)
	(?叁 ?三)
	(?肆 ?四)
	(?伍 ?五)
	(?陆 ?六)
	(?柒 ?七)
	(?捌 ?八)
	(?玖 ?九)
	(?拾 ?十)
	(?佰 ?百)
	(?仟 ?千)))

(dolist (item eon-chinese-numbers)
  (let ((uc (car item))
	(lc (cadr item)))
    (set-case-syntax-pair uc lc (standard-case-table))))

(provide 'eon-chinese)
