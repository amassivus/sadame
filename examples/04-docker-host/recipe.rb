# Docker Engine from Docker's own package repository on Debian, Ubuntu and
# Rocky Linux, and from the official repository on Arch; log rotation for
# containers; and users allowed to run docker.
family = platform.family
unless %w[debian rhel arch].include?(family)
  raise "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not #{platform.description}"
end

case family
when "debian"
  # Docker's repository and its signing key. A new repository needs a fresh
  # package index before the packages can be found, right away.
  package "ca-certificates"
  package "curl"
  directory "/etc/apt/keyrings", mode: "0755"
  exec "download Docker's signing key",
       command: "curl -fsSL https://download.docker.com/linux/#{platform.id}/gpg -o /etc/apt/keyrings/docker.asc",
       creates: "/etc/apt/keyrings/docker.asc"
  file "/etc/apt/sources.list.d/docker.list",
       content: "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/#{platform.id} " \
                "#{platform.codename} stable\n",
       mode: "0644",
       notifies: [:run, "exec[apt-get update]", :immediately]
  exec "apt-get update", action: :nothing
  vars[:docker_packages].each { |name| package name }
when "rhel"
  file "/etc/yum.repos.d/docker-ce.repo", source: "docker-ce.repo", mode: "0644"
  vars[:docker_packages].each { |name| package name }
when "arch"
  package "docker"
end

directory "/etc/docker", mode: "0755"
file "/etc/docker/daemon.json",
     template: "daemon.json.erb",
     mode: "0644",
     notifies: [:restart, "service[docker]"]

service "docker", enable: true, state: :running

# Members of the docker group can control the daemon, which is the same as
# root access. Only list people who have root anyway.
vars[:docker_users].each do |name|
  user name, shell: "/bin/bash", groups: ["docker"]
end
