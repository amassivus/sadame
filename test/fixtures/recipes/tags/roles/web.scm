(package "nginx")
(file "/etc/nginx/conf.d/app.conf" #:content "server {}\n" #:tags '(config)
      #:notifies '(reload "service[nginx]"))
(service "nginx" #:state 'running)
