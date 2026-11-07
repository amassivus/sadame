;; Hetzner Cloud: every server, grouped by its "role" label.
;;   sadame hosts --inventory hosts-hcloud.scm
(define servers
  (json-parse (command-output "hcloud server list -o json")))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(for-each
 (lambda (server)
   (let ((role (or (field (field server "labels") "role") "unassigned")))
     (group (string->symbol role)
       (host (field server "name")
             #:address (field (field (field server "public_net") "ipv4") "ip")
             #:user "root"))))
 servers)
