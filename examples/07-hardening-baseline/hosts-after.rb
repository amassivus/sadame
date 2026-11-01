# After the first apply: SSH listens on vars[:ssh_port] (2222) only.
group :new do
  host "vps1.example.com", user: "admin", sudo: true, port: 2222
end
