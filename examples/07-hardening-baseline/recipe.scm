;; The "run this on every new VM" baseline for Debian and Ubuntu: SSH on a
;; non-standard port with keys only, a firewall that allows only that port
;; (and any listed in vars), fail2ban for SSH, and automatic security updates.
;;
;; After the first apply, SSH listens on (vars 'ssh_port) only; connect to the
;; new port from then on (see hosts-after.scm).
(unless (equal? (platform 'family) "debian")
  (error (string-append "this example supports Debian and Ubuntu, not " (platform 'description))))

(define port (vars 'ssh_port))

;; open_ports is a list in vars.scm; --var open_ports=80,443 gives a string.
(define open-ports
  (let ((value (vars 'open_ports)))
    (if (list? value)
        value
        (filter (lambda (item) (not (string-null? item)))
                (map string-trim-both
                     (string-split (format #f "~a" (or value "")) #\,))))))

(package "openssh-server")
(package "ufw")
(package "fail2ban")
(package "unattended-upgrades")

;; sshd runs before its configuration changes: starting it creates
;; /run/sshd, which `sshd -t` needs to check the new file.
(service "ssh" #:enable #t #:state 'running)

;; Ubuntu 22.10 and later start sshd from ssh.socket, which listens on the
;; ports systemd generated from sshd_config at its last reload: restarting
;; sshd alone would leave SSH on port 22, behind a firewall that no longer
;; allows it. Where the socket is in use, regenerate its ports and restart
;; it. Debian starts sshd directly, and there this does nothing.
(exec "move ssh.socket to the new port"
      #:command (string-append "if systemctl is-enabled --quiet ssh.socket; then "
                               "systemctl daemon-reload && systemctl restart ssh.socket; fi")
      #:action 'nothing)

(file "/etc/ssh/sshd_config.d/10-hardening.conf"
      #:template "sshd-hardening.conf.tmpl"
      #:mode "0644"
      #:verify "sshd -t -f %{path}"
      #:notifies '((restart "service[ssh]") (run "exec[move ssh.socket to the new port]")))

;; Firewall: allow the SSH port before turning the firewall on, so the
;; connection running this recipe survives.
(exec "ufw default deny incoming" #:not-if "ufw status verbose | grep -q 'deny (incoming)'")
(for-each (lambda (open-port)
            (let ((rule (format #f "~a/tcp" open-port)))
              (exec (string-append "ufw allow " rule)
                    #:not-if (string-append "ufw show added | grep -qw 'allow " rule "'"))))
          (cons port open-ports))
(exec "ufw --force enable" #:not-if "ufw status | grep -q 'Status: active'")

(file "/etc/fail2ban/jail.d/sshd.local"
      #:template "fail2ban-sshd.local.tmpl"
      #:mode "0644"
      #:notifies '(restart "service[fail2ban]"))
(service "fail2ban" #:enable #t #:state 'running)

(file "/etc/apt/apt.conf.d/20auto-upgrades"
      #:content "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n"
      #:mode "0644")
(service "apt-daily-upgrade.timer" #:enable #t #:state 'running)
