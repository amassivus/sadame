# HTTPS with a certificate from Let's Encrypt, issued once and renewed by
# certbot's own timer. The certificate is requested only when it does not
# exist yet, so applying again never asks for a new one.
family = platform.family
nginx_user = { "debian" => "www-data", "rhel" => "nginx", "arch" => "http" }.fetch(family) do
  raise "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not #{platform.description}"
end
domain = vars[:domain]
webroot = "/var/www/#{domain}"
live = "/etc/letsencrypt/live/#{domain}"

package "epel-release" if family == "rhel" # certbot comes from EPEL there
package "nginx"
package "certbot"
service "nginx", enable: true, state: :running

# Port 80 must answer certbot's challenge before the certificate exists, so
# nginx reloads right away instead of at the end of the run.
file "/etc/nginx/nginx.conf",
     template: "nginx.conf.erb",
     locals: { user: nginx_user },
     mode: "0644",
     verify: "nginx -t -q -c %{path}",
     notifies: [:reload, "service[nginx]", :immediately]
directory "/etc/nginx/conf.d", mode: "0755"
directory webroot, mode: "0755"
file "#{webroot}/index.html", content: "<h1>#{domain}</h1>\n", mode: "0644"
file "/etc/nginx/conf.d/#{domain}.conf",
     template: "http.conf.erb",
     locals: { webroot: webroot },
     mode: "0644",
     notifies: [:reload, "service[nginx]", :immediately]

certbot = ["certbot certonly --webroot", "-w #{webroot}", "-d #{domain}",
           "--non-interactive --agree-tos", "-m #{vars[:email]}"]
certbot << "--server #{vars[:acme_server]}" if vars[:acme_server]
certbot << vars[:certbot_flags] unless vars[:certbot_flags].to_s.empty?
exec "request the certificate for #{domain}",
     command: certbot.join(" "),
     not_if: "test -f #{live}/fullchain.pem"

# The HTTPS server can only be configured once the certificate exists.
file "/etc/nginx/conf.d/#{domain}-tls.conf",
     template: "https.conf.erb",
     locals: { webroot: webroot, live: live },
     mode: "0644",
     notifies: [:reload, "service[nginx]"]

# Renewals reload nginx so it serves the new certificate.
directory "/etc/letsencrypt/renewal-hooks/deploy", mode: "0755"
file "/etc/letsencrypt/renewal-hooks/deploy/reload-nginx",
     content: "#!/bin/sh\nsystemctl reload nginx\n",
     mode: "0755"

renew_timer = { "debian" => "certbot.timer", "rhel" => "certbot-renew.timer" }[family]
service renew_timer, enable: true, state: :running if renew_timer
