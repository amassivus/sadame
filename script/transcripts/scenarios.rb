# frozen_string_literal: true

# Every terminal session shown in the docs. Each scenario runs in a fresh
# container of the named image; steps run in order, and a step with a save
# name is written to docs/transcripts/NAME.txt. Steps without one prepare
# the machine and are not shown.
module Transcripts
  SCENARIOS = [
    {
      name: "reference",
      image: "debian",
      steps: [
        { save: "cli-help", commands: ["sadame --help"] },
        { save: "cli-version", commands: ["sadame --version"] },
        { save: "cli-usage-error", commands: ["sadame plan examples/01-hello --colour", "echo $?"] }
      ]
    },
    {
      name: "getting-started",
      image: "debian",
      steps: [
        { save: "getting-started-plan", commands: ["sadame plan examples/01-hello"] },
        { save: "getting-started-apply", commands: ["sadame apply examples/01-hello"] },
        { save: "getting-started-plan-again", commands: ["sadame plan examples/01-hello"] },
        { save: "getting-started-edited",
          commands: ["echo 'Hello from someone else' > /tmp/sadame-hello.txt", "sadame plan examples/01-hello"] },
        { save: "getting-started-drift", commands: ["sadame drift examples/01-hello", "echo $?"] },
        { save: "getting-started-json", commands: ["sadame plan examples/01-hello --json"] }
      ]
    },
    {
      name: "basics",
      image: "debian",
      steps: [
        { save: "basics-plan", commands: ["sudo sadame plan examples/basics"] },
        { save: "basics-plan-maintenance",
          commands: ["sudo sadame plan examples/basics --var maintenance='Sundays 02:00-03:00 UTC'"] },
        { commands: ["sudo sadame apply examples/basics"] },
        { save: "basics-plan-contact", commands: ["sudo sadame plan examples/basics --var contact=platform@example.com"] }
      ]
    },
    {
      name: "basics-mistakes",
      image: "debian",
      steps: [
        { commands: [
          "mkdir -p /tmp/option-typo /tmp/template-typo/templates",
          "printf 'package \"git\"\\nfile \"/etc/motd\", contents: \"Welcome\\\\n\"\\n' > /tmp/option-typo/recipe.rb",
          "printf 'file \"/etc/app.conf\", template: \"app.conf.erb\"\\n' > /tmp/template-typo/recipe.rb",
          "printf '# Managed by sadame\\n[server]\\nport = <%%= port %%>\\n' > /tmp/template-typo/templates/app.conf.erb"
        ] },
        { save: "basics-unknown-option", dir: "/tmp/option-typo", commands: ["sudo sadame plan", "echo $?"] },
        { save: "basics-template-error", dir: "/tmp/template-typo", commands: ["sudo sadame plan", "echo $?"] },
        { save: "validate-error", dir: "/tmp/template-typo", commands: ["sadame validate", "echo $?"] }
      ]
    },
    {
      name: "package-debian",
      image: "debian",
      steps: [
        { save: "package-debian",
          commands: ["sudo sadame plan examples/resources/package", "sudo sadame apply examples/resources/package",
                     "sudo sadame plan examples/resources/package"] },
        { save: "package-by-family", commands: ["sudo sadame plan examples/resources/package/by_family.rb"] }
      ]
    },
    {
      name: "package-arch",
      image: "arch",
      steps: [
        { save: "package-arch",
          commands: ["sudo sadame plan examples/resources/package", "sudo sadame apply examples/resources/package",
                     "pacman -Q tree htop"] },
        { save: "package-aur", commands: ["sudo sadame plan examples/resources/package/aur.rb"] }
      ]
    },
    {
      name: "file",
      image: "debian",
      steps: [
        { save: "file-apply", commands: ["sudo sadame apply examples/resources/file"] },
        { save: "file-var", commands: ["sudo sadame plan examples/resources/file --var environment=production"] },
        { save: "file-chmod",
          commands: ["sudo chmod 0644 /etc/hello/hello.conf", "sudo sadame plan examples/resources/file"] }
      ]
    },
    {
      name: "directory",
      image: "debian",
      steps: [
        { save: "directory",
          commands: ["sudo sadame plan examples/resources/directory", "sudo sadame apply examples/resources/directory",
                     "sudo sadame plan examples/resources/directory"] }
      ]
    },
    {
      name: "service",
      image: "debian-systemd",
      steps: [
        { save: "service-install",
          commands: ["sudo sadame plan examples/resources/service", "sudo sadame apply examples/resources/service"] },
        { save: "service-repair",
          commands: ["sudo systemctl stop nginx", "sudo systemctl disable --quiet nginx",
                     "sudo sadame plan examples/resources/service", "sudo sadame apply examples/resources/service"] }
      ]
    },
    {
      name: "service-reload",
      image: "debian-systemd",
      steps: [
        { save: "service-reload", commands: ["sudo sadame apply examples/resources/service/reload_on_change.rb"] }
      ]
    },
    {
      name: "exec",
      image: "debian",
      steps: [
        { save: "exec-plan", commands: ["sudo sadame plan examples/resources/exec"] },
        { save: "exec-apply",
          commands: ["sudo sadame apply examples/resources/exec", "sudo sadame plan examples/resources/exec",
                     "cat /opt/demo/build-info.txt"] }
      ]
    },
    {
      name: "user",
      image: "debian",
      steps: [
        { save: "user-docker-group", commands: ["sudo sadame plan examples/resources/user/docker_group.rb"] },
        { save: "user",
          commands: ["sudo sadame plan examples/resources/user", "sudo sadame apply examples/resources/user",
                     "id deploy"] }
      ]
    },
    {
      name: "init",
      image: "debian",
      steps: [
        { save: "init", dir: "/tmp", commands: ["sadame init infra", "sadame validate infra"] },
        { save: "validate",
          commands: ["sadame validate examples/08-multi-role-inventory/site.rb -g all --platform ubuntu"] }
      ]
    },
    {
      name: "facts",
      image: "debian",
      steps: [
        { save: "facts-local", commands: ["sadame facts"] },
        { save: "facts-plan", commands: ["sudo sadame plan examples/facts"] }
      ]
    },
    {
      name: "service-openrc",
      image: "alpine-openrc",
      steps: [
        { save: "service-openrc",
          commands: ["sudo sadame apply examples/resources/service", "rc-update show default", "rc-service nginx status"] }
      ]
    },
    {
      name: "group",
      image: "debian",
      steps: [
        { save: "group",
          commands: ["sudo sadame plan examples/resources/group", "sudo sadame apply examples/resources/group",
                     "getent group app metrics"] }
      ]
    },
    {
      name: "link",
      image: "debian",
      steps: [
        { save: "link",
          commands: ["sudo sadame apply examples/resources/link", "readlink /srv/app/current /usr/local/bin/app-console",
                     "app-console"] },
        { save: "link-repoint",
          commands: ["sudo ln -sfn releases/1 /srv/app/current", "sudo sadame drift examples/resources/link",
                     "sudo sadame apply examples/resources/link"] }
      ]
    },
    {
      name: "line",
      image: "debian",
      steps: [
        { commands: ["sudo apt-get update -qq",
                     "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server >/dev/null"] },
        { save: "line-plan", commands: ["sudo sadame plan examples/resources/line"] },
        { save: "line-apply",
          commands: ["sudo sadame apply examples/resources/line", "sudo sadame plan examples/resources/line"] }
      ]
    },
    {
      name: "git",
      image: "debian",
      steps: [
        { save: "git",
          commands: ["sudo sadame apply examples/resources/git", "sudo sadame plan examples/resources/git",
                     "sudo -u deploy git -C /srv/sadame describe --tags"] }
      ]
    },
    {
      name: "notifications",
      image: "debian-systemd",
      steps: [
        { save: "notifications-first-apply", commands: ["sudo sadame apply examples/notifications"] },
        { save: "notifications-plan-interval", commands: ["sudo sadame plan examples/notifications --var interval=30"] },
        { save: "notifications-apply-interval", commands: ["sudo sadame apply examples/notifications --var interval=30"] },
        { save: "notifications-unit-change",
          commands: ["sudo sadame apply examples/notifications --var interval=30 --var description='Ticker demo'"] }
      ]
    },
    {
      name: "omarchy",
      image: "arch-systemd",
      steps: [
        { commands: ["useradd -m alice", "echo 'alice ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/alice",
                     "chmod 0440 /etc/sudoers.d/alice"] },
        { save: "omarchy-plan", user: "alice", commands: ["sudo sadame plan examples/12-omarchy-workstation"] },
        { save: "omarchy-apply", user: "alice", commands: ["sudo sadame apply examples/12-omarchy-workstation"] },
        { save: "omarchy-drift-clean", user: "alice",
          commands: ["sudo sadame drift examples/12-omarchy-workstation", "echo $?"] },
        { save: "omarchy-drift-broken", user: "alice",
          commands: ["sed -i 's/rebase = true/rebase = false/' ~/.gitconfig", "rm ~/.local/bin/update-system",
                     "sudo sadame drift examples/12-omarchy-workstation", "echo $?"] },
        { save: "omarchy-repair", user: "alice", commands: ["sudo sadame apply examples/12-omarchy-workstation"] }
      ]
    },
    {
      name: "drift-demo",
      image: "debian-systemd",
      steps: [
        { save: "drift-demo-apply", commands: ["sudo sadame apply examples/10-drift-demo"] },
        { save: "drift-demo-clean", commands: ["sudo sadame drift examples/10-drift-demo", "echo $?"] },
        { save: "drift-demo-break", commands: ["sudo sh examples/10-drift-demo/break-things.sh"] },
        { save: "drift-demo-drift", commands: ["sudo sadame drift examples/10-drift-demo", "echo $?"] },
        { save: "drift-demo-json", commands: ["sudo sadame drift examples/10-drift-demo --json"] },
        { save: "drift-demo-repair",
          commands: ["sudo sadame apply examples/10-drift-demo", "sudo sadame drift examples/10-drift-demo", "echo $?"] }
      ]
    }
  ].freeze

  # Sessions in the SSH lab of test/integration/push/lab.rb, run in its
  # controller. A step with target: runs its commands on that lab machine
  # instead, as root, and one with controller: true runs them in the
  # controller without recording them; neither is saved.
  EXAMPLE_08 = "/sadame/examples/08-multi-role-inventory"

  LAB_SCENARIOS = [
    {
      name: "remote",
      steps: [
        { save: "inventory-hosts", dir: EXAMPLE_08, commands: ["sadame hosts"] },
        { save: "inventory-hosts-var", dir: EXAMPLE_08, commands: ["sadame hosts --limit web2.example.com --var workers=16"] },
        { save: "remote-plan-web", dir: EXAMPLE_08, commands: ["sadame plan site.rb -g web"] },
        { save: "remote-apply-all", dir: EXAMPLE_08, commands: ["sadame apply site.rb -g all"] },
        { save: "remote-drift-clean", dir: EXAMPLE_08, commands: ["sadame drift site.rb -g all", "echo $?"] },
        { target: "web2", commands: ["sed -i 's/workers     = 8/workers     = 12/' /etc/demo-app/web.conf"] },
        { save: "remote-drift-limit", dir: EXAMPLE_08, commands: ["sadame drift site.rb --limit 'web*'", "echo $?"] },
        { save: "remote-drift-json", dir: EXAMPLE_08, commands: ["sadame drift site.rb -h web2.example.com --json"] },
        { controller: true, commands: ["cd #{EXAMPLE_08} && sadame drift site.rb --limit 'web*' --json > /tmp/drift.json"] },
        { save: "report-markdown", dir: "/tmp", commands: ["sadame report drift.json"] },
        { save: "report-junit", dir: "/tmp", commands: ["sadame report drift.json --format junit"] },
        { save: "remote-tags", dir: EXAMPLE_08, commands: ["sadame plan site.rb -g web --tags web"] },
        { save: "remote-host-flag", dir: EXAMPLE_08, commands: ["sadame plan site.rb -h deploy@db1.example.com:2222"] },
        { save: "remote-unreachable", dir: EXAMPLE_08,
          commands: ["sadame plan site.rb -g db -h deploy@db2.example.com", "echo $?"] },
        { save: "inventory-dynamic", dir: "/sadame/examples/11-dynamic-inventory", commands: ["sadame hosts -g db"] },
        { save: "remote-facts", dir: EXAMPLE_08, commands: ["sadame facts -h web1.example.com"] }
      ]
    },
    {
      name: "provision",
      steps: [
        { save: "vps-admin-user", dir: "/sadame",
          commands: ["sadame apply examples/06-app-deploy-user -h root@vps1.example.com " \
                     "--var \"ssh_keys=$(cat ~/.ssh/id_ed25519.pub)\" --var sudo_commands=ALL"] },
        { save: "vps-hardening", dir: "/sadame",
          commands: ["sadame apply examples/07-hardening-baseline -h deploy@vps1.example.com --sudo --var open_ports=80,443"] },
        { save: "vps-web", dir: "/sadame",
          commands: ["sadame apply examples/02-nginx-static-site -h deploy@vps1.example.com:2222 --sudo " \
                     "--var server_name=vps1.example.com"] },
        { save: "vps-check", dir: "/sadame",
          commands: ["sadame drift examples/07-hardening-baseline -h deploy@vps1.example.com:2222 --sudo " \
                     "--var open_ports=80,443", "echo $?",
                     "ssh -p 2222 root@vps1.example.com true", "ssh -p 22 deploy@vps1.example.com true"] }
      ]
    },
    {
      name: "remote-troubleshooting",
      steps: [
        { save: "trouble-permission-denied", dir: EXAMPLE_08, commands: ["sadame plan site.rb -h nobody@web1.example.com"] },
        { save: "trouble-wrong-port", dir: EXAMPLE_08, commands: ["sadame plan site.rb -h deploy@db1.example.com:22"] },
        { save: "trouble-sudo-password", dir: EXAMPLE_08,
          commands: ["sadame plan site.rb -h ops@web1.example.com --sudo"] },
        { save: "trouble-missing-binary", dir: EXAMPLE_08,
          commands: ["SADAME_BINARY_DIR=/opt/empty sadame plan site.rb -h web1.example.com"] },
        { controller: true,
          commands: ["ssh deploy@web1.example.com true",
                     "ssh-keygen -R web1.example.com",
                     "echo \"web1.example.com $(cut -d ' ' -f 1,2 /root/.ssh/id_ed25519.pub)\" >> /root/.ssh/known_hosts"] },
        { save: "trouble-host-key", dir: EXAMPLE_08, commands: ["sadame plan site.rb -h web1.example.com"] }
      ]
    },
    # --serial stopping a rollout: web2 has a file where the recipe wants a
    # directory, so its apply fails and db1, in the last batch, is skipped.
    # remote-troubleshooting leaves a wrong host key for web1 behind.
    {
      name: "rolling",
      steps: [
        { controller: true, commands: ["ssh-keygen -R web1.example.com",
                                       "cd #{EXAMPLE_08} && sadame apply site.rb -g all >/dev/null"] },
        { target: "web2", commands: ["rm -rf /etc/demo-app && touch /etc/demo-app"] },
        { save: "remote-serial", dir: EXAMPLE_08, commands: ["sadame apply site.rb -g all --serial 1", "echo $?"] },
        { target: "web2", commands: ["rm -f /etc/demo-app"] }
      ]
    },
    # The "see it work" block on the docs' home page: a var changed in
    # hosts.rb, rolled out to the db group. db1 is the group's only host,
    # so the output's line order does not change between captures, and the
    # page can quote line ranges of it. Last, so that the scenarios above
    # start from fresh servers.
    {
      name: "landing",
      steps: [
        { controller: true, commands: ["cd #{EXAMPLE_08} && sadame apply site.rb -g db >/dev/null"] },
        { controller: true,
          commands: ["rm -rf /tmp/fleet && cp -r #{EXAMPLE_08} /tmp/fleet",
                     "sed -i 's/backup_hour: 3/backup_hour: 4/' /tmp/fleet/hosts.rb"] },
        { save: "landing-plan", dir: "/tmp/fleet", commands: ["sadame plan site.rb -g db"] },
        { save: "landing-apply", dir: "/tmp/fleet", commands: ["sadame apply site.rb -g db"] },
        { save: "landing-drift", dir: "/tmp/fleet", commands: ["sadame drift site.rb -g db", "echo $?"] }
      ]
    }
  ].freeze
end
