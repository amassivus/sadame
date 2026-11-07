;; A static website behind nginx, on Debian/Ubuntu, Rocky/RHEL and Arch.
;; nginx's main configuration is managed too, so every distribution loads
;; /etc/nginx/conf.d/*.conf the same way and nothing else.
(define nginx-user
  (or (assoc-ref '(("debian" . "www-data") ("rhel" . "nginx") ("arch" . "http"))
                 (platform 'family))
      (error (string-append "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not "
                            (platform 'description)))))
(define root (string-append "/var/www/" (vars 'site_name)))

(package "nginx")
(service "nginx" #:enable #t #:state 'running)

(file "/etc/nginx/nginx.conf"
      #:template "nginx.conf.tmpl"
      #:locals `((user . ,nginx-user))
      #:mode "0644"
      #:verify "nginx -t -q -c %{path}"
      #:notifies '(reload "service[nginx]"))

(directory "/etc/nginx/conf.d" #:mode "0755")
(file (string-append "/etc/nginx/conf.d/" (vars 'site_name) ".conf")
      #:template "site.conf.tmpl"
      #:locals `((root . ,root))
      #:mode "0644"
      #:notifies '(reload "service[nginx]"))

(directory root #:mode "0755")
(file (string-append root "/index.html") #:template "index.html.tmpl" #:mode "0644")
