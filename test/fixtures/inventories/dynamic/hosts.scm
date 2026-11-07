(use-modules (srfi srfi-1))

(define servers
  (json-parse (read-text-file (string-append (source-directory) "/servers.json"))))

(define (field server name) (cdr (assoc name server)))

(for-each
 (lambda (role)
   (group (string->symbol role)
     (for-each (lambda (server)
                 (when (equal? (field server "role") role)
                   (host (field server "name") #:address (field server "ip"))))
               servers)))
 (delete-duplicates (map (lambda (server) (field server "role")) servers)))

(group 'listed
  (for-each host (string-split (string-trim-right (command-output "printf 'extra1\\nextra2\\n'") #\newline) #\newline)))
