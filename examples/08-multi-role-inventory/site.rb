# Every host gets the base below; the roles follow the host's groups in
# hosts.rb. Run it on all of them with: sadame apply site.rb -g all
file "/etc/motd", template: "motd.erb", locals: { name: host_name, groups: host_groups }

include_recipe "roles/web" if host_groups.include?(:web)
include_recipe "roles/db" if host_groups.include?(:db)
