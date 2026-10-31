# Every vars layer and connection option, for InventoryTest.
group :web do
  host "web1.example.com", vars: { layer: "host", from_host: "web1" }
  host "web2.example.com"
  vars layer: "group web", from_web: true
end

group :db do
  host "db1.example.com", user: "admin", port: 2222, sudo: true, ssh_opts: ["-i", "~/.ssh/db"]
end

group :all, include: [:web, :db] do
  vars layer: "group all", env: "production"
end

group :monitoring do
  host "web1.example.com"
  vars layer: "group monitoring"
end

host "standalone.example.com", address: "192.0.2.10"
