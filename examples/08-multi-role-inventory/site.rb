# Every host gets the base below; the roles follow the host's groups in
# hosts.rb. Run it on all of them with: sadame apply site.rb -g all
file "/etc/motd", template: "motd.erb", locals: { name: host_name, groups: host_groups }

# Each role's resources are tagged with the role, so --tags web plans or
# applies only the web role, without the base.
include_recipe "roles/web", tags: [:web] if host_groups.include?(:web)
include_recipe "roles/db", tags: [:db] if host_groups.include?(:db)
