# Changelog

All notable changes to this project are documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `sadame plan` and `sadame apply` for the local machine, with a colored
  unified diff, per-resource results, `--json` output and documented exit
  statuses.
- Resources: `package` (apt, dnf, apk, pacman), `file` (content, template,
  source, mode, owner, group), `directory`, `service` (systemd), `exec`
  (`creates`, `not_if`, `only_if`, `cwd`, `env`) and `user`.
- `sadame drift`: compares like `plan` and exits 1 when the machine differs
  from the recipe; `--json` for CI. Exit statuses are documented per
  command (0 success, 1 failure or drift, 2 usage, recipe or state-read
  error).
- Notifications: `notifies:` and `subscribes:`, delayed (once, at the end
  of `apply`) by default or `:immediately`; `exec` with `action: :nothing`
  for commands that only run when notified.
- A summary table and the run time at the end of `apply`.
- Inventories: `hosts.rb` with `group`, `host` (`address`, `user`,
  `port`, `sudo`, `ssh_opts`, `vars`), `include:` and group `vars`;
  `command_output` for dynamic inventories. Vars precedence: `--var`, host,
  group (including over included), `vars.rb`.
- Push mode: `-h [user@]host[:port]`, `-g`, `--limit`, `--inventory`,
  `--sudo`. Sadame copies itself (cached by checksum under `~/.sadame/bin/`)
  and the recipe with the system's `scp`, runs over `ssh`, all hosts in
  parallel with prefixed output, and ends with a per-host summary or one
  JSON document.
- `sadame hosts`: the selected hosts with their connection options and
  vars, and where each var came from.
- `host_name` and `host_groups` in recipes; `--host-name`, `--host-groups`
  and `--vars-file` for local runs.
- `file` checks new content with `verify:` (such as `visudo -cf %{path}`)
  before it replaces the target; `service` manages units of a user's
  systemd instance with `user:`; `platform.codename`.
- Examples 01 to 12, from a one-file hello to a hardened VPS, PostgreSQL,
  Docker, a multi-role inventory and an Omarchy workstation, plus Ansible
  and Itamae migration examples and CI pipelines for plan, apply and drift.
- Docker integration tests: every example on Ubuntu, Debian, Rocky, Alpine
  and Arch, on amd64 and arm64 (QEMU in CI), in containers booting systemd;
  certbot against Pebble. A local-only VM layer (`rake vm:test`).
- JSON report fields `drift`, `exit_status`, `duration_seconds`, and the
  notifications each resource triggers; documented in the JSON output
  reference.
- Recipe DSL with `include_recipe`, `vars` from `vars.rb` and `--var`, and
  `platform` facts read from `/etc/os-release`.
- An ERB-compatible template engine (`<%= %>`, `<% %>`, `<%# %>`, `-%>`,
  `<%-`, `<%%`).
- mruby build (`rake build:native`) and a test suite that runs on CRuby and
  inside the mruby build.
- Release binaries: static Linux builds for amd64 and arm64 (built with
  musl in Docker) and macOS builds for Apple silicon and Intel, each about
  1 MB. CI runs the Linux binaries unmodified in Ubuntu, Debian, Rocky,
  Alpine and Arch images (Arch Linux ARM, a community image, for arm64),
  the arm64 ones under QEMU, before they can be published.
- `install.sh`: installs the right binary for the system after checking its
  SHA-256 checksum.
- Release workflow: a `v*` tag publishes the binaries, `SHA256SUMS` and the
  changelog section as a GitHub release.
