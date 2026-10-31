file "/etc/motd", content: "#{host_name}\n"
include_recipe "roles/web" if host_groups.include?(:web)
