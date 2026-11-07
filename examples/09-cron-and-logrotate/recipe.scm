;; Scheduled jobs and log rotation for an application, with plain files in
;; /etc/cron.d and /etc/logrotate.d: no special resource needed.
(define cron
  (or (assoc-ref '(("debian" . ("cron" "cron"))
                   ("rhel" . ("cronie" "crond"))
                   ("arch" . ("cronie" "cronie")))
                 (platform 'family))
      (error (string-append "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not "
                            (platform 'description)))))
(define cron-package (car cron))
(define cron-service (cadr cron))

(package cron-package)
(package "logrotate")
(service cron-service #:enable #t #:state 'running)

(user "app" #:system #t #:home "/var/lib/app" #:shell "/usr/sbin/nologin")
(directory "/var/lib/app" #:owner "app" #:mode "0750")
(directory "/var/log/app" #:owner "app" #:mode "0750")

;; One file per application in /etc/cron.d; cron rereads it by itself.
(file "/etc/cron.d/app" #:template "cron.tmpl" #:mode "0644")

;; logrotate checks the file in debug mode before it is installed.
(file "/etc/logrotate.d/app" #:template "logrotate.tmpl" #:mode "0644" #:verify "logrotate -d %{path}")
