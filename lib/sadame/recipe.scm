;;; The recipe language. Every name exported here is available in a recipe.
;;;
;;;   (package "nginx")
;;;   (directory "/var/www/app" #:owner "www-data" #:mode "0755")
;;;   (file "/etc/nginx/nginx.conf" #:template "nginx.conf.tmpl"
;;;         #:notifies '(reload "service[nginx]"))
;;;   (service "nginx" #:enable #t #:state 'running)
;;;   (exec "certbot --nginx -d example.com"
;;;         #:not-if "test -f /etc/letsencrypt/live/example.com/fullchain.pem")
;;;   (user "deploy" #:shell "/bin/bash" #:groups '("docker"))
;;;   (group "app" #:gid 1500)
;;;   (link "/etc/nginx/sites-enabled/app" #:to "/etc/nginx/sites-available/app")
;;;   (line "PermitRootLogin no" #:path "/etc/ssh/sshd_config"
;;;         #:match "^#?\\s*PermitRootLogin\\s")
;;;   (git "/srv/app" #:repository "https://github.com/example/app.git" #:revision "v1.4.2")
;;;   (include-recipe "roles/web" #:tags '(web))
;;;
;;; (vars 'key), (platform 'family), (facts 'cpus), (host-name) and
;;; (host-groups) are there for decisions in plain Scheme. Options are
;;; keywords; #:not-if and #:not_if are the same option.

(define-module (sadame recipe)
  #:use-module (sadame primitives)
  #:use-module (sadame eval)
  #:export (package file directory service exec user group link line git
            include-recipe platform facts vars host-name host-groups)
  #:re-export (json-parse source-directory read-text-file))

(define (package name . options) (%declare 'package name options))
(define (file path . options) (%declare 'file path options))
(define (directory path . options) (%declare 'directory path options))
(define (service name . options) (%declare 'service name options))
(define (exec command . options) (%declare 'exec command options))
(define (user name . options) (%declare 'user name options))
(define (group name . options) (%declare 'group name options))
(define (link path . options) (%declare 'link path options))
(define (line name . options) (%declare 'line name options))
(define (git path . options) (%declare 'git path options))

;; Evaluates another recipe, relative to this recipe's directory. The ".scm"
;; extension is optional. A recipe is only ever included once. With #:tags,
;; every resource it declares (and the recipes it includes) gets those tags.
(define (include-recipe name . options) (%include-recipe name options))

;; What the machine runs: (platform 'family), (platform 'id), 'name,
;; 'version, 'codename, 'kernel, 'package-manager, 'description. Without an
;; argument, all of them as an association list.
(define (platform . key) (apply %platform key))

;; What the machine has: CPUs, memory, addresses and more, read from it when
;; first asked for. (facts 'cpus), (facts 'memory-mb), ...
(define (facts . key) (apply %facts key))

;; The run's vars: (vars 'name), (vars 'name default), or all of them.
(define (vars . key) (apply %vars key))

;; The name of the host being configured: its name in hosts.scm or -h, or
;; "local" (see --host-name).
(define (host-name) (%host-name))

;; The groups the host belongs to in hosts.scm, as symbols, including groups
;; that include them. Empty for local runs (see --host-groups).
(define (host-groups) (%host-groups))
