;; -*- lexical-binding: t; -*-

(defun eon-git-util-repo-info-arg (remote-url)
  "返回一个函数，该函数可以获取当前git仓库的不同属性
支持的属性包括：
'name - 仓库名称
'host - 仓库域名
'url - 远程URL"
  (cl-destructuring-bind (host name)
      (when remote-url
        (cond
         ((string-match "git@\\([^:/]+\\):\\(.*\\)" remote-url)
	  (list (match-string 1 remote-url) (match-string 2 remote-url)))
         ((string-match "://\\([^/]+\\)/\\(.*\\)" remote-url)
	  (list (match-string 1 remote-url) (match-string 2 remote-url)))))
    (lambda (property)
      (pcase property
	('name name)
	('host host)
	('url remote-url)
	(_ (error "未知属性：%s" property))))))

(defun eon-git-util-repo-info ()
  "返回一个函数，该函数可以获取当前git仓库的不同属性
支持的属性包括：
'name - 仓库名称
'host - 仓库域名
:url - 远程URL"
  (let* ((remote-url (string-trim
		      (shell-command-to-string
		       "git config --get remote.origin.url"))))
    (eon-git-util-repo-info-arg remote-url)))

(provide 'eon-git-util)
