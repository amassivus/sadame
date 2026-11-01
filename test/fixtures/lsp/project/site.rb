file "/etc/motd", content: "Questions: #{vars[:contact]}\n"
include_recipe "roles/web" if host_groups.include?(:web)
