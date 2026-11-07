;; AWS EC2: running instances, named and grouped by their Name and Role tags.
;;   sadame hosts --inventory hosts-aws.scm
(use-modules (srfi srfi-1))

(define reply
  (json-parse (command-output (string-append "aws ec2 describe-instances "
                                             "--filters Name=instance-state-name,Values=running --output json"))))

(define (field alist key)
  (let ((entry (assoc key alist)))
    (and entry (cdr entry))))

(for-each
 (lambda (reservation)
   (for-each
    (lambda (instance)
      (let ((tags (map (lambda (tag) (cons (field tag "Key") (field tag "Value")))
                       (or (field instance "Tags") '())))
            (address (field instance "PublicIpAddress")))
        (when address
          (group (string->symbol (or (assoc-ref tags "Role") "unassigned"))
            (host (or (assoc-ref tags "Name") (field instance "InstanceId"))
                  #:address address
                  #:user "ec2-user")))))
    (field reservation "Instances")))
 (field reply "Reservations"))
