;; PostgreSQL with its settings tuned through vars, on Debian, Ubuntu, Rocky
;; and Arch. The tuning goes into its own file in a conf.d directory, so the
;; distribution's postgresql.conf stays as it was installed.
(define family (platform 'family))
(define data-dir #f)
(define conf-dir #f)

(cond
 ((equal? family "debian")
  (let ((version (or (vars 'postgres_version)
                     ;; vars turns the keys of nested lists into symbols
                     (assq-ref (vars 'debian_postgres_versions)
                               (string->symbol (string-append (platform 'id) " " (platform 'version)))))))
    (unless version
      (error (string-append "set --var postgres_version=N for " (platform 'description))))
    (package "postgresql") ; creates and starts a cluster; its postgresql.conf includes conf.d
    (set! conf-dir (format #f "/etc/postgresql/~a/main/conf.d" version))))
 ((member family '("rhel" "arch"))
  (set! data-dir (if (equal? family "rhel") "/var/lib/pgsql/data" "/var/lib/postgres/data"))
  (let ((initdb (if (equal? family "rhel")
                    "postgresql-setup --initdb"
                    (string-append "runuser -u postgres -- initdb --locale=C.UTF-8 --encoding=UTF8 -D "
                                   data-dir))))
    (package (if (equal? family "rhel") "postgresql-server" "postgresql"))
    (exec "create the database cluster"
          #:command initdb
          #:creates (string-append data-dir "/PG_VERSION")))
  (set! conf-dir (string-append data-dir "/conf.d")))
 (else
  (error (string-append "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not "
                        (platform 'description)))))

;; A quarter of the memory is PostgreSQL's usual starting point.
(define shared-buffers
  (or (vars 'shared_buffers)
      (format #f "~aMB" (quotient (facts 'memory_mb) 4))))

;; The settings exist before PostgreSQL starts, so it never sees an
;; include_dir that points nowhere.
(directory conf-dir #:owner "postgres" #:group "postgres" #:mode "0700")
(file (string-append conf-dir "/tuning.conf")
      #:template "tuning.conf.tmpl"
      #:locals `((shared_buffers . ,shared-buffers))
      #:owner "postgres"
      #:group "postgres"
      #:mode "0640"
      #:notifies '(restart "service[postgresql]"))
(when data-dir
  ;; Rocky's and Arch's postgresql.conf has include_dir commented out; this
  ;; turns that line into one that reads conf.d.
  (line "include_dir = 'conf.d'"
        #:path (string-append data-dir "/postgresql.conf")
        #:match "^#?\\s*include_dir\\s*="
        #:notifies '(restart "service[postgresql]")))

(service "postgresql" #:enable #t #:state 'running)
