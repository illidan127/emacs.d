;; -*- lexical-binding: t; -*-

;;; emacs  性能分析相关

(defun eon-toggle-profiler-cpu ()
  (interactive)
  (if (profiler-cpu-running-p)
      (profiler-stop)
    (profiler-start 'cpu)))

(define-key global-map (kbd "C-<f12>") #'eon-toggle-profiler-cpu)
