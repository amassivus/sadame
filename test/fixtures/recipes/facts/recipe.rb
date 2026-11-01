file "/etc/app.conf", template: "app.conf.erb"
file "/etc/cpus", content: "#{facts[:cpus]}\n" unless facts[:container]
