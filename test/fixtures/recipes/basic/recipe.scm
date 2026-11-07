;; A recipe that touches every resource type, used by recipe and CLI tests.
(package "nginx")

(directory "/var/www/app" #:owner "www-data" #:mode "0755")

(file "/etc/nginx/conf.d/app.conf"
      #:template "app.conf.tmpl"
      #:mode "0644"
      #:notifies '(reload "service[nginx]"))

(include-recipe "roles/web")
(include-recipe "roles/web.scm")

(when (vars 'with_user)
  (user "deploy" #:shell "/bin/bash"))
