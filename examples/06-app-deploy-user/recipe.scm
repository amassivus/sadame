;; A user for deployments: login shell, the team's SSH keys, and a sudoers
;; drop-in that lets it restart the application and nothing else.
(define name (vars 'user))
(define home (string-append "/home/" name))

;; One key or command given with --var is a string; lists live in vars.scm.
(define (as-list value)
  (cond ((list? value) value)
        (value (list (format #f "~a" value)))
        (else (list ""))))
(define keys (as-list (vars 'ssh_keys)))
(define commands (as-list (vars 'sudo_commands)))

(package "sudo")
(when (equal? (platform 'family) "alpine")
  (package "shadow") ; useradd and usermod
  (package "bash"))

(user name #:shell "/bin/bash")

(directory (string-append home "/.ssh") #:owner name #:mode "0700")
(file (string-append home "/.ssh/authorized_keys")
      #:template "authorized_keys.tmpl"
      #:locals `((keys . ,keys))
      #:owner name
      #:mode "0600")

;; visudo checks the file before it is installed: a broken sudoers file can
;; lock everyone out of sudo.
(file (string-append "/etc/sudoers.d/" name)
      #:template "sudoers.tmpl"
      #:locals `((commands . ,commands))
      #:owner "root"
      #:mode "0440"
      #:verify "visudo -cf %{path}")
