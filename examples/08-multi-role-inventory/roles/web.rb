# Web servers: nginx in front of a small app whose worker count comes from
# vars (4 for the group, 8 for web2).
package "nginx"

directory "/etc/demo-app", mode: "0755"
file "/etc/demo-app/web.conf", template: "web.conf.erb", mode: "0644"

file "/etc/nginx/conf.d/demo-app.conf",
     template: "nginx-demo-app.conf.erb",
     mode: "0644",
     notifies: [:reload, "service[nginx]"]

service "nginx", enable: true, state: :running
