;; After the first apply: SSH listens on (vars 'ssh_port) (2222) only.
(group 'new
  (host "vps1.example.com" #:user "admin" #:sudo #t #:port 2222))
