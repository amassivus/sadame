# A web server in three resources (Debian and Ubuntu paths).
package "nginx"
file "/var/www/html/index.html", content: "Hello from sadame\n", mode: "0644"
service "nginx", enable: true, state: :running
