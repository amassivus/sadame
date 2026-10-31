# Reload nginx when its configuration changes. The reload runs once, at the
# end of apply, and only if the file changed.
package "nginx"

file "/etc/nginx/conf.d/status.conf",
     content: "server {\n  listen 127.0.0.1:8080;\n  location = /status { stub_status; }\n}\n",
     mode: "0644",
     notifies: [:reload, "service[nginx]"]

service "nginx", enable: true, state: :running
