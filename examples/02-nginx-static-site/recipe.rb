# A static website behind nginx, on Debian/Ubuntu, Rocky/RHEL and Arch.
# nginx's main configuration is managed too, so every distribution loads
# /etc/nginx/conf.d/*.conf the same way and nothing else.
nginx_user = { "debian" => "www-data", "rhel" => "nginx", "arch" => "http" }.fetch(platform.family) do
  raise "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not #{platform.description}"
end
root = "/var/www/#{vars[:site_name]}"

package "nginx"
service "nginx", enable: true, state: :running

file "/etc/nginx/nginx.conf",
     template: "nginx.conf.erb",
     locals: { user: nginx_user },
     mode: "0644",
     verify: "nginx -t -q -c %{path}",
     notifies: [:reload, "service[nginx]"]

directory "/etc/nginx/conf.d", mode: "0755"
file "/etc/nginx/conf.d/#{vars[:site_name]}.conf",
     template: "site.conf.erb",
     locals: { root: root },
     mode: "0644",
     notifies: [:reload, "service[nginx]"]

directory root, mode: "0755"
file "#{root}/index.html", template: "index.html.erb", mode: "0644"
