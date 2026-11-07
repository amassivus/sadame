;; Every vars layer and connection option, for the inventory tests.
(group 'web
  (host "web1.example.com" #:vars '((layer . "host") (from-host . "web1")))
  (host "web2.example.com")
  (vars #:layer "group web" #:from-web #t))

(group 'db
  (host "db1.example.com" #:user "admin" #:port 2222 #:sudo #t #:ssh-opts '("-i" "~/.ssh/db")))

(group 'all #:include '(web db)
  (vars #:layer "group all" #:env "production"))

(group 'monitoring
  (host "web1.example.com")
  (vars #:layer "group monitoring"))

(host "standalone.example.com" #:address "192.0.2.10")
