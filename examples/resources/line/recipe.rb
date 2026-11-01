# The SSH server's configuration belongs to its package. Each line resource
# changes one line and leaves the rest of the file as it was shipped, and
# sshd -t checks the edited file before it replaces the real one.
package({ "arch" => "openssh" }.fetch(platform.family, "openssh-server"))
# sshd -t needs host keys and, on Debian and Ubuntu, /run/sshd. Most
# packages leave both to the service's first start.
exec "ssh-keygen -A", creates: "/etc/ssh/ssh_host_ed25519_key"
directory "/run/sshd", mode: "0755" if platform.family == "debian"

# Replaces the line that sets the option, commented out or not; appends it
# when no line does.
line "PermitRootLogin no",
     path: "/etc/ssh/sshd_config",
     match: /^#?\s*PermitRootLogin\s/,
     verify: "sshd -t -f %{path}"

line "PasswordAuthentication no",
     path: "/etc/ssh/sshd_config",
     match: /^#?\s*PasswordAuthentication\s/,
     verify: "sshd -t -f %{path}"

# Removes the line if it is there. Debian ships it; sshd's default is "no".
line "no X11 forwarding",
     path: "/etc/ssh/sshd_config",
     line: "X11Forwarding yes",
     state: :absent,
     verify: "sshd -t -f %{path}"
