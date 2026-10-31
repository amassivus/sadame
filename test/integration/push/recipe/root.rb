# Needs root: run with sudo.
file "/etc/sadame-lab.conf", content: "managed by sadame on #{host_name}\n", mode: "0600"
