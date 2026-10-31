# frozen_string_literal: true

# Every terminal session shown in the docs. Each scenario runs in a fresh
# container of the named image; steps run in order, and a step with a save
# name is written to docs/transcripts/NAME.txt. Steps without one prepare
# the machine and are not shown.
module Transcripts
  SCENARIOS = [
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
        { save: "basics-template-error", dir: "/tmp/template-typo", commands: ["sudo sadame plan", "echo $?"] }
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
end
