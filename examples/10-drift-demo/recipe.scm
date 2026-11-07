;; A small server to watch drift on: a package, a system user, a config file
;; and a service. Paths are Debian and Ubuntu's.
(package "nginx")

(user "demo-app" #:system #t #:home "/var/lib/demo-app" #:shell "/usr/sbin/nologin")

(directory "/etc/demo-app" #:mode "0755")

(file "/etc/demo-app/app.conf"
      #:template "app.conf.tmpl"
      #:owner "root"
      #:group "demo-app"
      #:mode "0640")

(service "nginx" #:enable #t #:state 'running)
