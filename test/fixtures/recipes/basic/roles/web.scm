(service "nginx" #:enable #t #:state 'running)

(exec "touch /var/www/app/.ready" #:creates "/var/www/app/.ready")
