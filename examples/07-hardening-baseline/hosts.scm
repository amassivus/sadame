;; Before the first apply: SSH still listens on port 22.
(group 'new
  (host "vps1.example.com" #:user "admin" #:sudo #t))
