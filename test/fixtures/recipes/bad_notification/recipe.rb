file "/etc/app.conf", content: "x", notifies: [:restart, "service[app]"]
