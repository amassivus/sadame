# frozen_string_literal: true

# Where every example runs. The unit tests plan and apply each example on a
# fake machine of every distribution listed here; the Docker integration
# tests (test/integration/docker) run them for real in containers.
#
#   path      a recipe file, or a directory containing recipe.rb
#   distros   where it runs; the others are skipped with why:
#   why       why it does not run on the other distributions: one reason,
#             or a Hash of reasons by distribution
#   runs      argument lists for sadame; each is applied, then checked with
#             drift (default: one run without arguments)
#   vm_runs   the same for the VM layer, where hosts.local.rb provides what
#             the containers get from arguments (default: runs)
#   setup     shell commands that prepare a container before the first run
#   pebble    true when the container needs the Pebble test ACME server
#   emulated  why it cannot run where the container's CPU is emulated
#             (QEMU user mode); it still runs on native machines
#   systemd   true when it needs a service manager running (systemd, or
#             OpenRC on Alpine): it declares services or runs systemctl or
#             loginctl
#   drift_demo true for 10-drift-demo, which also breaks the machine
module ExampleMatrix
  ALL = %w[ubuntu debian rocky alpine arch].freeze
  SYSTEMD = %w[ubuntu debian rocky arch].freeze
  DEBIAN = %w[ubuntu debian].freeze
  NOT_ALPINE = "it covers Debian/Ubuntu, Rocky/RHEL and Arch, not Alpine"

  EXAMPLES = [
    { path: "examples/01-hello", distros: ALL },
    { path: "examples/02-nginx-static-site", systemd: true, distros: SYSTEMD, why: NOT_ALPINE },
    { path: "examples/03-nginx-tls-certbot", systemd: true, distros: SYSTEMD, why: NOT_ALPINE, pebble: true,
      runs: [["--var", "domain=site.example.test", "--var", "email=admin@example.test",
              "--var", "acme_server=https://pebble:14000/dir", "--var", "certbot_flags=--no-verify-ssl"]] },
    { path: "examples/04-docker-host", systemd: true, distros: SYSTEMD, why: NOT_ALPINE,
      emulated: "Docker's daemon needs iptables, which does not work under QEMU user emulation" },
    { path: "examples/05-postgres", systemd: true, distros: SYSTEMD, why: NOT_ALPINE },
    { path: "examples/06-app-deploy-user", distros: ALL },
    { path: "examples/07-hardening-baseline", systemd: true, distros: DEBIAN,
      why: "ufw and unattended-upgrades are Debian's and Ubuntu's",
      emulated: "ufw needs iptables, which does not work under QEMU user emulation" },
    { path: "examples/08-multi-role-inventory/site.rb", systemd: true, distros: DEBIAN,
      why: "the roles use Debian's package names and paths",
      runs: [["--host-name", "web1.example.com", "--host-groups", "web,all"],
             ["--host-name", "db1.example.com", "--host-groups", "db,all"]], vm_runs: [[]] },
    { path: "examples/09-cron-and-logrotate", systemd: true, distros: SYSTEMD, why: NOT_ALPINE },
    { path: "examples/10-drift-demo", systemd: true, distros: DEBIAN, why: "it uses Debian's nginx and nologin paths",
      drift_demo: true },
    { path: "examples/11-dynamic-inventory/recipe.rb", distros: ALL },
    { path: "examples/12-omarchy-workstation", systemd: true, distros: ["arch"],
      why: "it is for Arch Linux and Omarchy",
      setup: ["useradd -m alice"], runs: [["--var", "user=alice"]], vm_runs: [[]] },
    { path: "examples/migrate-from-ansible", systemd: true, distros: DEBIAN,
      why: "the playbook it translates uses apt" },
    { path: "examples/migrate-from-itamae", systemd: true, distros: DEBIAN, why: "it uses Debian's www-data user" },
    { path: "examples/basics", distros: %w[ubuntu debian alpine arch],
      why: "Rocky ships curl-minimal, which conflicts with the curl package" },
    { path: "examples/quickstart", systemd: true, distros: DEBIAN, why: "it writes Debian's default web root" },
    { path: "examples/notifications", systemd: true, distros: SYSTEMD, why: "it writes a systemd unit" },
    { path: "examples/resources/package/recipe.rb", distros: %w[ubuntu debian alpine arch],
      why: "htop needs EPEL on Rocky" },
    { path: "examples/resources/package/minimal.rb", distros: %w[ubuntu debian alpine arch],
      why: "htop needs EPEL on Rocky" },
    { path: "examples/resources/package/by_family.rb", distros: %w[ubuntu debian rocky],
      why: { "arch" => "Arch calls the package apache, not httpd",
             "alpine" => "Alpine calls the package apache2, not httpd" } },
    { path: "examples/resources/package/aur.rb", distros: ["arch"], why: "the AUR is Arch's",
      runs: [["--var", "aur_user=alice"]], vm_runs: [[]] },
    { path: "examples/resources/file/recipe.rb", distros: ALL },
    { path: "examples/resources/file/minimal.rb", distros: ALL },
    { path: "examples/resources/directory/recipe.rb", distros: DEBIAN, why: "it uses Debian's www-data user" },
    { path: "examples/resources/directory/minimal.rb", distros: ALL },
    { path: "examples/resources/service/recipe.rb", systemd: true, distros: ALL },
    { path: "examples/resources/service/reload_on_change.rb", systemd: true, distros: %w[ubuntu debian rocky],
      why: { "arch" => "Arch's nginx.conf does not include conf.d",
             "alpine" => "Alpine's nginx.conf includes http.d, not conf.d" } },
    { path: "examples/resources/exec/recipe.rb", distros: ALL },
    { path: "examples/resources/exec/minimal.rb", distros: DEBIAN, why: "/var/backups is Debian's" },
    { path: "examples/resources/user/recipe.rb", distros: SYSTEMD, why: "Alpine needs the shadow package first" },
    { path: "examples/resources/user/minimal.rb", distros: SYSTEMD, why: "Alpine needs the shadow package first" },
    { path: "examples/resources/user/docker_group.rb", distros: DEBIAN, why: "docker.io is Debian's package name" },
    { path: "examples/resources/user/remove.rb", distros: SYSTEMD, why: "Alpine needs the shadow package first" },
    { path: "examples/resources/group/recipe.rb", distros: ALL },
    { path: "examples/resources/group/minimal.rb", distros: ALL },
    { path: "examples/resources/link/recipe.rb", distros: ALL },
    { path: "examples/resources/line/recipe.rb", distros: ALL },
    { path: "examples/resources/line/minimal.rb", distros: ALL },
    { path: "examples/resources/git/recipe.rb", distros: ALL },
    { path: "examples/resources/git/minimal.rb", distros: ALL },
    { path: "examples/facts", distros: ALL },
    { path: "examples/shared-recipes/site.rb", distros: ALL }
  ].freeze

  # The recipe file of an example.
  def self.recipe_path(example)
    path = example[:path]
    path.end_with?(".rb") ? path : "#{path}/recipe.rb"
  end

  def self.skip_reason(example, distro)
    reason = example[:why]
    reason.is_a?(Hash) ? reason.fetch(distro) : reason
  end

  def self.runs(example)
    example[:runs] || [[]]
  end

  def self.vm_runs(example)
    example[:vm_runs] || runs(example)
  end
end
