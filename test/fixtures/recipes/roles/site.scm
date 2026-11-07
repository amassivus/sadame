(file "/etc/motd" #:content (string-append (host-name) "\n"))
(when (memq 'web (host-groups))
  (include-recipe "roles/web"))
