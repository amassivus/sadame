# itamae/recipe.rb, translated. Resource names mostly stay; blocks become
# keyword options; node becomes vars; template variables become locals.
package "nginx"
package "openssl"

file "/etc/nginx/conf.d/app.conf",
     template: "app.conf.erb",
     locals: { server_name: vars[:server_name], workers: vars[:workers] },
     mode: "644",
     notifies: [:reload, "service[nginx]"]

directory "/srv/app", owner: "www-data", mode: "755"

file "/usr/local/bin/backup", source: "backup.sh", mode: "755"

exec "self-signed certificate",
     command: "openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj /CN=app.example.com " \
              "-keyout /etc/ssl/private/app.key -out /etc/ssl/certs/app.crt",
     not_if: "test -f /etc/ssl/private/app.key"

user "deploy", shell: "/bin/bash"

service "nginx", enable: true, state: :running
