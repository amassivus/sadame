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
