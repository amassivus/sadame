# The "run this on every new VM" baseline for Debian and Ubuntu: SSH on a
# non-standard port with keys only, a firewall that allows only that port
# (and any listed in vars), fail2ban for SSH, and automatic security updates.
#
# After the first apply, SSH listens on vars[:ssh_port] only; connect to the
# new port from then on (see hosts-after.rb).
raise "this example supports Debian and Ubuntu, not #{platform.description}" unless platform.family == "debian"

port = vars[:ssh_port]

package "openssh-server"
package "ufw"
package "fail2ban"
package "unattended-upgrades"

file "/etc/ssh/sshd_config.d/10-hardening.conf",
     template: "sshd-hardening.conf.erb",
     mode: "0644",
     verify: "sshd -t -f %{path}",
     notifies: [:restart, "service[ssh]"]
service "ssh", enable: true, state: :running

# Firewall: allow the SSH port before turning the firewall on, so the
# connection running this recipe survives.
exec "ufw default deny incoming", not_if: "ufw status verbose | grep -q 'deny (incoming)'"
([port] + vars[:open_ports]).each do |open_port|
  exec "ufw allow #{open_port}/tcp", not_if: "ufw show added | grep -qw 'allow #{open_port}/tcp'"
end
exec "ufw --force enable", not_if: "ufw status | grep -q 'Status: active'"

file "/etc/fail2ban/jail.d/sshd.local",
     template: "fail2ban-sshd.local.erb",
     mode: "0644",
     notifies: [:restart, "service[fail2ban]"]
service "fail2ban", enable: true, state: :running

file "/etc/apt/apt.conf.d/20auto-upgrades",
     content: "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n",
     mode: "0644"
service "apt-daily-upgrade.timer", enable: true, state: :running
