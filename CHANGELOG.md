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
- `notifies:` with delayed notifications that run once at the end of
  `apply`.
- Recipe DSL with `include_recipe`, `vars` from `vars.rb` and `--var`, and
  `platform` facts read from `/etc/os-release`.
- An ERB-compatible template engine (`<%= %>`, `<% %>`, `<%# %>`, `-%>`,
  `<%-`, `<%%`).
- mruby build (`rake build:native`) and a test suite that runs on CRuby and
  inside the mruby build.
