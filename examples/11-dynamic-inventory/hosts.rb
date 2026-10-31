# A dynamic inventory: hosts.rb is Ruby, so it can build the host list from
# any data. This one reads servers.json, which another tool might write.
# Paths are relative to where you run sadame, so build them from __FILE__.
servers = JSON.parse(File.read(File.join(File.dirname(__FILE__), "servers.json")))

servers.group_by { |server| server["role"] }.each do |role, members|
  group role.to_sym do
    members.each do |server|
      options = { address: server["address"], user: "deploy" }
      options[:port] = server["port"] if server["port"]
      host server["name"], options
    end
  end
end

group :all, include: [:web, :db] do
  vars env: "production"
end
