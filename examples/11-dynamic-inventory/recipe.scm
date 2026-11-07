;; A small recipe to run against the dynamic inventory.
(file "/etc/motd"
      #:content (string-append (host-name) " (" (vars 'env) ")\nManaged by sadame.\n")
      #:mode "0644")
