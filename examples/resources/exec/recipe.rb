directory "/opt/demo"

# creates: skip when the path exists.
exec "tar -czf /opt/demo/etc-backup.tar.gz -C /etc hostname hosts",
     creates: "/opt/demo/etc-backup.tar.gz"

# not_if: skip when the command succeeds.
exec "echo 'EDITOR=vim' >> /etc/environment",
     not_if: "grep -qs '^EDITOR=vim$' /etc/environment"

# only_if: run only when the command succeeds. Here: only on hosts with git,
# and only until the setting is in place.
exec "git config --system init.defaultBranch main",
     only_if: "command -v git",
     not_if: "git config --system --get init.defaultBranch"

# cwd: and env: set the working directory and environment.
exec "echo \"built by $BUILDER\" > build-info.txt",
     cwd: "/opt/demo",
     env: { "BUILDER" => "sadame" },
     creates: "/opt/demo/build-info.txt"
