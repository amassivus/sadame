;; HTTPS with a certificate from Let's Encrypt, issued once and renewed by
;; certbot's own timer. The certificate is requested only when it does not
;; exist yet, so applying again never asks for a new one.
(define family (platform 'family))
(define nginx-user
  (or (assoc-ref '(("debian" . "www-data") ("rhel" . "nginx") ("arch" . "http")) family)
      (error (string-append "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not "
                            (platform 'description)))))
(define domain (vars 'domain))
(define webroot (string-append "/var/www/" domain))
(define live (string-append "/etc/letsencrypt/live/" domain))

(when (equal? family "rhel")
  (package "epel-release")) ; certbot comes from EPEL there
(package "nginx")
(package "certbot")
(service "nginx" #:enable #t #:state 'running)

;; Port 80 must answer certbot's challenge before the certificate exists, so
;; nginx reloads right away instead of at the end of the run.
(file "/etc/nginx/nginx.conf"
      #:template "nginx.conf.tmpl"
      #:locals `((user . ,nginx-user))
      #:mode "0644"
      #:verify "nginx -t -q -c %{path}"
      #:notifies '(reload "service[nginx]" immediately))
(directory "/etc/nginx/conf.d" #:mode "0755")
(directory webroot #:mode "0755")
(file (string-append webroot "/index.html")
      #:content (string-append "<h1>" domain "</h1>\n")
      #:mode "0644")
(file (string-append "/etc/nginx/conf.d/" domain ".conf")
      #:template "http.conf.tmpl"
      #:locals `((webroot . ,webroot))
      #:mode "0644"
      #:notifies '(reload "service[nginx]" immediately))

(define (present? value)
  (and value (not (equal? value ""))))

(define certbot
  (append (list "certbot certonly --webroot"
                (string-append "-w " webroot)
                (string-append "-d " domain)
                "--non-interactive --agree-tos"
                (string-append "-m " (vars 'email)))
          (if (present? (vars 'acme_server))
              (list (string-append "--server " (vars 'acme_server)))
              '())
          (if (present? (vars 'certbot_flags))
              (list (vars 'certbot_flags))
              '())))
(exec (string-append "request the certificate for " domain)
      #:command (string-join certbot " ")
      #:not-if (string-append "test -f " live "/fullchain.pem"))

;; The HTTPS server can only be configured once the certificate exists.
(file (string-append "/etc/nginx/conf.d/" domain "-tls.conf")
      #:template "https.conf.tmpl"
      #:locals `((webroot . ,webroot) (live . ,live))
      #:mode "0644"
      #:notifies '(reload "service[nginx]"))

;; Renewals reload nginx so it serves the new certificate.
(directory "/etc/letsencrypt/renewal-hooks/deploy" #:mode "0755")
(file "/etc/letsencrypt/renewal-hooks/deploy/reload-nginx"
      #:content "#!/bin/sh\nsystemctl reload nginx\n"
      #:mode "0755")

(define renew-timer
  (assoc-ref '(("debian" . "certbot.timer") ("rhel" . "certbot-renew.timer")) family))
(when renew-timer
  (service renew-timer #:enable #t #:state 'running))
