# Lab inventory. db1 is the same machine as in examples/08 (port 2222);
# app1.internal is only reachable through the bastion (see ../ssh_config).
group :db do
  host "db1.example.com", user: "deploy", port: 2222
end

group :internal do
  host "app1.internal", ssh_opts: ["-F", "/sadame/test/integration/push/ssh_config"]
end

group :all, include: [:db, :internal] do
  vars greeting: "hello from the lab"
end
