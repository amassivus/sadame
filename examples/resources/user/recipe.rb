# A login user who belongs to at least the adm group.
user "deploy", shell: "/bin/bash", groups: ["adm"]

# A system user without a login shell.
user "svc-backup", system: true, home: "/var/lib/svc-backup", shell: "/usr/sbin/nologin"
