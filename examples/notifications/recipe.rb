# A small systemd service whose unit file and settings are managed here.
# Notifications keep the running process in step with those files.

# Runs only when notified.
exec "systemctl daemon-reload", action: :nothing

# systemd must re-read a changed unit file before the service below is
# started or restarted, so daemon-reload runs immediately. The restart can
# wait until the end of the run.
file "/etc/systemd/system/ticker.service",
     template: "ticker.service.erb",
     mode: "0644",
     notifies: [
       [:run, "exec[systemctl daemon-reload]", :immediately],
       [:restart, "service[ticker]"]
     ]

# Settings the service reads when it starts.
file "/etc/default/ticker", content: "INTERVAL=#{vars[:interval]}\n", mode: "0644"

# The service asks to be restarted when its settings change; this is the
# same as notifies: on the file above, declared from the other side.
service "ticker",
        enable: true,
        state: :running,
        subscribes: [:restart, "file[/etc/default/ticker]"]
