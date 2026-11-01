# The Itamae recipe that ../recipe.rb translates, kept for comparison.
# Run with Itamae: itamae local itamae/recipe.rb -j itamae/node.json
package 'nginx'
package 'openssl'

template '/etc/nginx/conf.d/app.conf' do
  source 'templates/app.conf.erb'
  mode '644'
  variables(server_name: node[:server_name], workers: node[:workers])
  notifies :reload, 'service[nginx]'
end

directory '/srv/app' do
  owner 'www-data'
  mode '755'
end

remote_file '/usr/local/bin/backup' do
  source 'files/backup.sh'
  mode '755'
end

execute 'self-signed certificate' do
  command 'openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj /CN=app.example.com ' \
          '-keyout /etc/ssl/private/app.key -out /etc/ssl/certs/app.crt'
  not_if 'test -f /etc/ssl/private/app.key'
end

user 'deploy' do
  shell '/bin/bash'
end

service 'nginx' do
  action [:enable, :start]
end
