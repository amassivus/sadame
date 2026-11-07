;;; The hosts.scm language.
;;;
;;;   (group 'web
;;;     (host "web1.example.com")
;;;     (host "web2.example.com" #:vars '((workers . 8)))
;;;     (vars #:workers 4 #:tls #t))
;;;
;;;   (group 'db
;;;     (host "db1.example.com" #:user "admin" #:port 2222 #:sudo #t))
;;;
;;;   (group 'all #:include '(web db)
;;;     (vars #:env "production"))
;;;
;;; Vars precedence, highest first: --var, host vars, group vars (a group
;;; overrides the groups it includes), vars.scm.

(define-module (sadame inventory)
  #:use-module (sadame primitives)
  #:use-module (sadame eval)
  #:export (group host vars command-output)
  #:re-export (json-parse source-directory read-text-file))

;; Declares a group, or adds to one declared earlier. The forms after the
;; optional #:include run inside it.
(define-syntax group
  (syntax-rules ()
    ((_ name #:include includes body ...)
     (call-with-group name includes (lambda () (if #f #f) body ...)))
    ((_ name body ...)
     (call-with-group name '() (lambda () (if #f #f) body ...)))))

(define (call-with-group name includes thunk)
  (%inventory-group-begin name includes)
  (dynamic-wind
    (lambda () #f)
    thunk
    %inventory-group-end))

;; Declares a host, in the current group if inside one.
;;
;;   (host "db1.example.com" #:user "admin" #:port 2222 #:sudo #t
;;         #:ssh-opts '("-i" "~/.ssh/db") #:vars '((role . "primary")))
(define (host name . options) (%inventory-host name options))

;; Sets vars for the current group: (vars #:workers 4) or (vars '((workers . 4))).
(define (vars . arguments) (%inventory-vars arguments))

;; Runs a command on the machine running sadame and returns what it printed;
;; fails when the command does. For dynamic inventories:
;;
;;   (define servers (json-parse (command-output "hcloud server list -o json")))
(define (command-output command) (%command-output command))
