# A user for deployments: login shell, the team's SSH keys, and a sudoers
# drop-in that lets it restart the application and nothing else.
name = vars[:user]
home = "/home/#{name}"
# Lists in vars.rb; one key or command with --var gives a string.
keys = vars[:ssh_keys].is_a?(Array) ? vars[:ssh_keys] : [vars[:ssh_keys].to_s]
commands = vars[:sudo_commands].is_a?(Array) ? vars[:sudo_commands] : [vars[:sudo_commands].to_s]

package "sudo"
if platform.family == "alpine"
  package "shadow" # useradd and usermod
  package "bash"
end

user name, shell: "/bin/bash"

directory "#{home}/.ssh", owner: name, mode: "0700"
file "#{home}/.ssh/authorized_keys", template: "authorized_keys.erb", locals: { keys: keys }, owner: name,
                                      mode: "0600"

# visudo checks the file before it is installed: a broken sudoers file can
# lock everyone out of sudo.
file "/etc/sudoers.d/#{name}",
     template: "sudoers.erb",
     locals: { commands: commands },
     owner: "root",
     mode: "0440",
     verify: "visudo -cf %{path}"
