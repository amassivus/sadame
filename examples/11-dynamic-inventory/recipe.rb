# A small recipe to run against the dynamic inventory.
file "/etc/motd", content: "#{host_name} (#{vars[:env]})\nManaged by sadame.\n", mode: "0644"
