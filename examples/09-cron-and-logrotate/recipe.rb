# Scheduled jobs and log rotation for an application, with plain files in
# /etc/cron.d and /etc/logrotate.d: no special resource needed.
cron_package, cron_service = {
  "debian" => ["cron", "cron"],
  "rhel" => ["cronie", "crond"],
  "arch" => ["cronie", "cronie"]
}.fetch(platform.family) do
  raise "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not #{platform.description}"
end

package cron_package
package "logrotate"
service cron_service, enable: true, state: :running

user "app", system: true, home: "/var/lib/app", shell: "/usr/sbin/nologin"
directory "/var/lib/app", owner: "app", mode: "0750"
directory "/var/log/app", owner: "app", mode: "0750"

# One file per application in /etc/cron.d; cron rereads it by itself.
file "/etc/cron.d/app", template: "cron.erb", mode: "0644"

# logrotate checks the file in debug mode before it is installed.
file "/etc/logrotate.d/app", template: "logrotate.erb", mode: "0644", verify: "logrotate -d %{path}"
