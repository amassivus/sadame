;; Three servers in two roles. The names are placeholders: replace them with
;; yours, or point them at real machines in ~/.ssh/config.
(group 'web
  (host "web1.example.com" #:user "deploy" #:sudo #t)
  (host "web2.example.com" #:user "deploy" #:sudo #t #:vars '((workers . 8)))
  (vars #:workers 4 #:server_name "www.example.com"))

(group 'db
  ;; sshd listens on a non-standard port here.
  (host "db1.example.com" #:user "deploy" #:port 2222 #:sudo #t)
  (vars #:backup_hour 3))

(group 'all #:include '(web db)
  (vars #:env "production"))
