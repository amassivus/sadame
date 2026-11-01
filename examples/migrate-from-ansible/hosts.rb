# ansible/inventory.ini and ansible/inventory.yml, translated. Ansible's
# all group is implicit; here it is declared, including the other groups.
group :web do
  host "web1.example.com"
  host "web2.example.com", vars: { workers: 8 }
  vars workers: 4
end

group :db do
  host "db1.example.com", user: "admin", port: 2222, sudo: true
end

group :all, include: [:web, :db] do
  vars env: "production"
end
