# A recipe that touches every resource type, used by recipe and CLI tests.
package "nginx"

directory "/var/www/app", owner: "www-data", mode: "0755"

file "/etc/nginx/conf.d/app.conf",
     template: "app.conf.erb",
     mode: "0644",
     notifies: [:reload, "service[nginx]"]

include_recipe "roles/web"
include_recipe "roles/web.rb"

if vars[:with_user]
  user "deploy", shell: "/bin/bash"
end
