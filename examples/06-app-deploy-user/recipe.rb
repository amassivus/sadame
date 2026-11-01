# A user for deployments: login shell, the team's SSH keys, and a sudoers
# drop-in that lets it restart the application and nothing else.
name = vars[:user]
home = "/home/#{name}"

package "sudo"
if platform.family == "alpine"
  package "shadow" # useradd and usermod
  package "bash"
end

user name, shell: "/bin/bash"

directory "#{home}/.ssh", owner: name, mode: "0700"
file "#{home}/.ssh/authorized_keys", template: "authorized_keys.erb", owner: name, mode: "0600"

# visudo checks the file before it is installed: a broken sudoers file can
# lock everyone out of sudo.
file "/etc/sudoers.d/#{name}",
     template: "sudoers.erb",
     owner: "root",
     mode: "0440",
     verify: "visudo -cf %{path}"
