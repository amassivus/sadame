# What a recipe can know about the machine it runs on. Each fact is read on
# that machine the first time the recipe asks for it.

# A login banner that says what this machine is; the template reads facts too.
file "/etc/motd", template: "motd.erb", mode: "0644"

# An application sized to the machine: two workers per CPU, an eighth of the
# memory for its cache, listening on the address of the default route.
directory "/etc/demo-app", mode: "0755"
file "/etc/demo-app/app.conf",
     content: "workers = #{facts[:cpus] * 2}\n" \
              "cache_mb = #{facts[:memory_mb] / 8}\n" \
              "listen = #{facts[:ipv4] || "127.0.0.1"}:8080\n",
     mode: "0644"

# A nightly job at a minute of its own, so that a fleet does not start it at
# the same moment. machine_id does not change, so neither does the minute.
seed = facts[:machine_id] || facts[:hostname]
minute = seed.bytes.inject(0) { |sum, byte| sum + byte } % 60
file "/etc/demo-app/nightly.schedule", content: "#{minute} 4 * * *\n", mode: "0644"

# Kernel settings belong to the host, not to a container that shares its kernel.
unless facts[:container]
  directory "/etc/sysctl.d", mode: "0755"
  file "/etc/sysctl.d/90-demo-app.conf", content: "net.core.somaxconn = 4096\n", mode: "0644"
end
