# Three servers in two roles. The names are placeholders: replace them with
# yours, or point them at real machines in ~/.ssh/config.
group :web do
  host "web1.example.com", user: "deploy", sudo: true
  host "web2.example.com", user: "deploy", sudo: true, vars: { workers: 8 }
  vars workers: 4, server_name: "www.example.com"
end

group :db do
  # sshd listens on a non-standard port here.
  host "db1.example.com", user: "deploy", port: 2222, sudo: true
  vars backup_hour: 3
end

group :all, include: [:web, :db] do
  vars env: "production"
end
