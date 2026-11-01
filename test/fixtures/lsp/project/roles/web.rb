package "nginx"
file "/etc/app.conf",
     template: "app.conf.erb",
     mode: "0644"
service "nginx", state: :running
