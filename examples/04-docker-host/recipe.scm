;; Docker Engine from Docker's own package repository on Debian, Ubuntu and
;; Rocky Linux, and from the official repository on Arch; log rotation for
;; containers; and users allowed to run docker.
(define family (platform 'family))
(unless (member family '("debian" "rhel" "arch"))
  (error (string-append "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not "
                        (platform 'description))))

(cond
 ((equal? family "debian")
  ;; Docker's repository and its signing key. A new repository needs a fresh
  ;; package index before the packages can be found, right away.
  (package "ca-certificates")
  (package "curl")
  (directory "/etc/apt/keyrings" #:mode "0755")
  (exec "download Docker's signing key"
        #:command (string-append "curl -fsSL https://download.docker.com/linux/"
                                 (platform 'id)
                                 "/gpg -o /etc/apt/keyrings/docker.asc")
        #:creates "/etc/apt/keyrings/docker.asc")
  (file "/etc/apt/sources.list.d/docker.list"
        #:content (string-append "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/"
                                 (platform 'id) " " (platform 'codename) " stable\n")
        #:mode "0644"
        #:notifies '(run "exec[apt-get update]" immediately))
  (exec "apt-get update" #:action 'nothing)
  (for-each package (vars 'docker_packages)))
 ((equal? family "rhel")
  (file "/etc/yum.repos.d/docker-ce.repo" #:source "docker-ce.repo" #:mode "0644")
  (for-each package (vars 'docker_packages)))
 ((equal? family "arch")
  (package "docker")))

(directory "/etc/docker" #:mode "0755")
(file "/etc/docker/daemon.json"
      #:template "daemon.json.tmpl"
      #:mode "0644"
      #:notifies '(restart "service[docker]"))

(service "docker" #:enable #t #:state 'running)

;; Members of the docker group can control the daemon, which is the same as
;; root access. Only list people who have root anyway.
(for-each (lambda (name)
            (user name #:shell "/bin/bash" #:groups '("docker")))
          (vars 'docker_users))
