# frozen_string_literal: true

module Sadame
  # `sadame init`: the files a new project starts from, and optionally a CI
  # job that checks the servers for drift every day. Nothing that exists is
  # overwritten: when any of the files is already there, nothing is written.
  class Scaffold
    CI_SYSTEMS = %w[github gitlab].freeze

    RECIPE = <<~RUBY
      # What the machines should look like. Each resource describes one thing:
      # a package, a file, a service. See what would change with `sadame plan`,
      # change it with `sadame apply`, check it later with `sadame drift`.
      #
      # Every resource: https://enderkus.github.io/sadame/resources/package/

      # A login banner from templates/motd.erb, with values from vars.rb and
      # the machine's facts.
      file "/etc/motd", template: "motd.erb", mode: "0644"

      # More to start from:
      #
      #   package "nginx"
      #   service "nginx", enable: true, state: :running
      #   user "deploy", shell: "/bin/bash", groups: ["sudo"]
      #   line "PermitRootLogin no", path: "/etc/ssh/sshd_config", match: /^#?\\s*PermitRootLogin\\s/
    RUBY

    VARS = <<~RUBY
      # Values for the recipe and its templates, as vars[:name]. hosts.rb can
      # set them per group and per host, and --var name=value wins over both.
      {
        contact: "ops@example.com"
      }
    RUBY

    HOSTS = <<~RUBY
      # The servers sadame manages over SSH, in groups. List them with
      # `sadame hosts`; plan for a group with `sadame plan -g web`.
      #
      # group :web do
      #   host "web1.example.com", user: "deploy", sudo: true
      #   host "web2.example.com", user: "deploy", sudo: true
      # end
      #
      # group :db do
      #   host "db1.example.com", user: "deploy", port: 2222, sudo: true
      #   vars contact: "dba@example.com"
      # end
      #
      # group :all, include: [:web, :db]
    RUBY

    MOTD = <<~ERB
      <%= facts[:fqdn] %>: <%= facts[:cpus] %> CPUs, <%= facts[:memory_mb] %> MB of memory
      Managed by sadame; changes made here by hand will be undone.
      Questions: <%= vars[:contact] %>
    ERB

    # The CI jobs, with RECIPE for the recipe's path. examples/ci has the
    # same jobs (a test keeps them equal), with comments for copying them.
    GITHUB = <<~YAML
      name: Drift

      on:
        schedule:
          - cron: "0 6 * * *"
        workflow_dispatch:

      jobs:
        drift:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v7

            - name: Install sadame
              run: curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh

            - name: Set up SSH
              run: |
                install -d -m 0700 ~/.ssh
                printf '%s\\n' "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_ed25519
                chmod 0600 ~/.ssh/id_ed25519
                printf '%s\\n' "${{ secrets.SSH_KNOWN_HOSTS }}" > ~/.ssh/known_hosts

            # Exit status: 0 no drift, 1 drift on a server, 2 a server could not be
            # checked. Anything but 0 fails this step and the workflow.
            - name: Check for drift
              run: sadame drift RECIPE -g all --json > drift.json

            - name: Summarize
              if: always()
              run: sadame report drift.json >> "$GITHUB_STEP_SUMMARY"

            - name: Keep the drift report
              if: always()
              uses: actions/upload-artifact@v7
              with:
                name: drift-report
                path: drift.json
    YAML

    GITLAB = <<~YAML
      drift:
        image: alpine:3.20
        rules:
          - if: $CI_PIPELINE_SOURCE == "schedule"
          - if: $CI_PIPELINE_SOURCE == "web"
        before_script:
          - apk add --no-cache openssh-client
          - wget -qO- https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
          - install -d -m 0700 ~/.ssh
          - printf '%s\\n' "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
          - chmod 0600 ~/.ssh/id_ed25519
          - printf '%s\\n' "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
        script:
          # Exit status: 0 no drift, 1 drift on a server, 2 a server could not be checked.
          - sadame drift RECIPE -g all --json > drift.json
        after_script:
          - sadame report drift.json --format junit > drift.xml
        artifacts:
          when: always
          paths:
            - drift.json
          reports:
            junit: drift.xml
          expire_in: 30 days
    YAML

    GITHUB_HEADER = <<~TEXT
      # Checks the servers for drift every morning and fails the workflow when
      # one differs from the recipe; the run's summary page shows what differs.
      # Written by `sadame init`.
      #
      # It needs repository secrets SSH_PRIVATE_KEY (a key the hosts.rb users
      # accept) and SSH_KNOWN_HOSTS (the output of `ssh-keyscan` for every
      # server), passwordless sudo on the servers if the recipe needs root, and
      # a group named all in hosts.rb.
    TEXT

    GITLAB_HEADER = <<~TEXT
      # Checks the servers for drift in scheduled pipelines and fails the job
      # when one differs from the recipe; the pipeline's test report shows what
      # differs. Written by `sadame init`.
      #
      # Include it from .gitlab-ci.yml and create a pipeline schedule:
      #
      #   include:
      #     - local: .gitlab/sadame-drift.yml
      #
      # It needs CI/CD variables SSH_PRIVATE_KEY and SSH_KNOWN_HOSTS (masked,
      # protected), passwordless sudo on the servers if the recipe needs root,
      # and a group named all in hosts.rb.
    TEXT

    def self.github_job(recipe)
      GITHUB.gsub("RECIPE", recipe)
    end

    def self.gitlab_job(recipe)
      GITLAB.gsub("RECIPE", recipe)
    end

    # directory is where the project goes; ci is nil, "github" or "gitlab".
    # CI files go in the current directory, the repository's root.
    def initialize(shell, directory, ci: nil)
      @shell = shell
      @directory = directory
      @ci = ci
    end

    # Returns the paths written.
    def files
      result = {
        in_directory("recipe.rb") => RECIPE,
        in_directory("vars.rb") => VARS,
        in_directory("hosts.rb") => HOSTS,
        in_directory("templates/motd.erb") => MOTD
      }
      recipe = in_directory("recipe.rb")
      result[".github/workflows/sadame-drift.yml"] = GITHUB_HEADER + "\n" + Scaffold.github_job(recipe) if @ci == "github"
      result[".gitlab/sadame-drift.yml"] = GITLAB_HEADER + "\n" + Scaffold.gitlab_job(recipe) if @ci == "gitlab"
      result
    end

    def write
      existing = files.keys.select { |path| File.exist?(path) }
      unless existing.empty?
        raise UsageError, "init writes nothing when one of its files exists, and these do: #{existing.join(", ")}"
      end

      files.each do |path, content|
        directory = File.dirname(path)
        @shell.run!("mkdir -p #{Shell.escape(directory)}") unless directory == "."
        @shell.write_file(path, content)
      end
      files.keys
    end

    private

    def in_directory(name)
      @directory == "." ? name : File.join(@directory, name)
    end
  end
end
