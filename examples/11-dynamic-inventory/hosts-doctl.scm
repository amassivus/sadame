;; DigitalOcean: every Droplet, in one group per tag.
;;   sadame hosts --inventory hosts-doctl.scm
(use-modules (srfi srfi-1))

(define droplets
  (json-parse (command-output "doctl compute droplet list --output json")))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(for-each
 (lambda (droplet)
   (let ((public-ip (find (lambda (network) (equal? (field network "type") "public"))
                          (field (field droplet "networks") "v4"))))
     (when public-ip
       (for-each
        (lambda (tag)
          (group (string->symbol tag)
            (host (field droplet "name")
                  #:address (field public-ip "ip_address")
                  #:user "root")))
        (field droplet "tags")))))
 droplets)
