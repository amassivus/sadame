;; Every host gets the base below; the roles follow the host's groups in
;; hosts.scm. Run it on all of them with: sadame apply site.scm -g all
(file "/etc/motd"
      #:template "motd.tmpl"
      #:locals `((name . ,(host-name)) (groups . ,(host-groups))))

;; Each role's resources are tagged with the role, so --tags web plans or
;; applies only the web role, without the base.
(when (memq 'web (host-groups))
  (include-recipe "roles/web" #:tags '(web)))
(when (memq 'db (host-groups))
  (include-recipe "roles/db" #:tags '(db)))
