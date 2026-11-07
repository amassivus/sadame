;; A dynamic inventory: hosts.scm is Scheme, so it can build the host list
;; from any data. This one reads servers.json, which another tool might write.
;; Paths are relative to where you run sadame, so build them from
;; (source-directory), the directory of this file.
(use-modules (srfi srfi-1))

(define servers
  (json-parse (read-text-file (string-append (source-directory) "/servers.json"))))

(define (field server key)
  (let ((entry (assoc key server)))
    (and entry (cdr entry))))

(for-each
 (lambda (role)
   (group (string->symbol role)
     (for-each (lambda (server)
                 (when (equal? (field server "role") role)
                   (apply host (field server "name")
                          #:address (field server "address")
                          #:user "deploy"
                          (if (field server "port")
                              (list #:port (field server "port"))
                              '()))))
               servers)))
 (delete-duplicates (map (lambda (server) (field server "role")) servers)))

(group 'all #:include '(web db)
  (vars #:env "production"))
