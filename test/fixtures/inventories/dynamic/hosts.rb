servers = JSON.parse(File.read(File.join(File.dirname(__FILE__), "servers.json")))

servers.group_by { |server| server["role"] }.each do |role, members|
  group role.to_sym do
    members.each { |server| host server["name"], address: server["ip"] }
  end
end

group :listed do
  command_output("printf 'extra1\\nextra2\\n'").split("\n").each { |name| host name }
end
