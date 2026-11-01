group :web do
  host "web1.example.com"
  host "web2.example.com"
  vars workers: 4
end

group :db do
  host "db1.example.com"
end
