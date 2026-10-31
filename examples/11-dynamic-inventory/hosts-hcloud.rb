# Hetzner Cloud: every server, grouped by its "role" label.
#   sadame hosts --inventory hosts-hcloud.rb
servers = JSON.parse(command_output("hcloud server list -o json"))

servers.each do |server|
  role = server["labels"]["role"] || "unassigned"
  group role.to_sym do
    host server["name"], address: server["public_net"]["ipv4"]["ip"], user: "root"
  end
end
