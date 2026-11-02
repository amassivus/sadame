# Changelog

All notable changes to this project are documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- A Japanese README, `README.ja.md`; a test keeps its code and output the
  same as the English one's.

### Changed

- The README shows a real plan, many servers, how push mode works, every
  command and resource, and where sadame stands.
- The Docker, push and VM tests, and the docs' transcript capture, stop
  before they start when a binary they need in `dist/` is older than the
  source, and name the task that rebuilds it.

### Fixed

- With sudo, push mode checks that sudo works without a password before it
  copies anything to a server, as the Remote hosts guide says. It used to
  copy the binary first, then fail.
- A misspelled option in a call that spans several lines is reported on
  its own line by `validate`, `plan`, `apply` and `drift`, as the language
  server already did. The binary used to name the call's last line.

## [0.5.0] - 2026-11-02

Editor support, and recipes shared between projects.

### Added

- `sadame lsp`, a language server: editors show what `validate` finds as
  you type, on the right file and line, complete resources, options,
  `state:` values and facts, describe them on hover, and list a recipe's
  resources in the outline. A file a recipe includes is checked through
  that recipe, for the hosts that include it. The Editor support guide
  sets it up in Neovim, Helix and Emacs.
- The Sharing recipes guide: recipes shared between projects as git
  submodules, pinned and updated on purpose, with an example project.
- The release binaries' smoke test runs `validate`, `facts`, `init`,
  `report` and a language server session too, in every distribution image
  and on macOS.

### Fixed

- Push mode leaves every `.git` out of the recipe it copies to servers,
  not only the top one, so a submodule's history stays behind.
- The resource pages list the `tags` option.

## [0.4.0] - 2026-11-01

Checking recipes without servers, running part of a recipe, and reports
for CI.

### Added

- `sadame validate` evaluates the recipe for each selected host, with its
  name, groups and vars, against a stand-in machine (`--platform debian`,
  `ubuntu`, `rocky`, `alpine` or `arch`), renders its templates, and
  connects to nothing.
- Tags: resources take `tags:`, `include_recipe "roles/web", tags: [:web]`
  tags everything a file declares, and `--tags` and `--skip-tags` run part
  of a recipe with `plan`, `apply` and `drift`. Reports list the tags used.
- `sadame report` turns the `--json` output of `plan`, `apply` and `drift`
  into Markdown for a CI summary page, or JUnit XML (`--format junit`) for
  test reports.
- `sadame init` writes a recipe, `vars.rb`, `hosts.rb` and a template, and
  with `--ci github` or `--ci gitlab` a daily drift check.

### Changed

- The CI examples put a drift summary on the GitHub Actions run page and a
  JUnit report in GitLab; the pull request pipeline validates the recipe
  before planning.
- Example 08 tags each role.
- `sadame hosts` says when `hosts.rb` exists but declares no hosts.

## [0.3.0] - 2026-11-01

Recipes can see the machine they run on.

### Added

- `facts` in recipes and templates: `hostname`, `fqdn`, `arch`, `kernel`,
  `cpus`, `memory_mb`, `swap_mb`, `root_disk_gb`, `ipv4`,
  `default_interface`, `ipv4_addresses`, `ipv6_addresses`,
  `virtualization`, `container`, `service_manager` and `machine_id`, read
  on the machine when first asked for. What cannot be read is nil; an
  unknown name is an error that lists the facts.
- `sadame facts` prints the facts of this machine, or with `-h`, `-g` or
  `--limit` of each selected host over SSH; `--json` as well.

### Changed

- Example 05 sizes PostgreSQL's `shared_buffers` to a quarter of the
  machine's memory unless vars set it.

## [0.2.0] - 2026-11-01

Rolling changes across a fleet, four more resource types, and Alpine
services.

### Added

- `--forks N` works on at most N hosts at once.
- `--serial N` or `--serial N%` runs the hosts in batches, one after
  another, and stops after a batch in which a host failed or could not be
  reached. The hosts of later batches are reported as `skipped`.
- The `line` resource manages one line in a file that a package owns:
  lines that match `match:` are replaced, otherwise the line is appended.
  `verify:` checks the edited file first, and plan shows the edit as a
  diff of the file.
- The `link` resource manages symbolic links; `force: true` replaces a
  regular file in the way.
- The `group` resource manages local groups and their gid, with BusyBox's
  `addgroup` and `delgroup` on an Alpine without `shadow`.
- The `git` resource keeps a checkout at a tag, a branch or a commit, and
  moves it when the branch moves. With `user:`, git runs as that user.
- `service` works with OpenRC, so on Alpine too.
- Homebrew tap: `brew install enderkus/sadame/sadame` installs the release
  binary on macOS and Linux.
- The docs' home page shows the navigation, the terminal recording and what
  sets sadame apart, with buttons to get started and to star the project.
- Links to the project on X, [@sadame_rb](https://x.com/sadame_rb), in the
  docs' footer and the README.

### Changed

- In push mode's JSON, `hosts[].exit_status` is `null` for hosts that
  `--serial` skipped.
- Example 05 sets PostgreSQL's `include_dir` with `line` instead of a
  guarded `exec`, and the Ansible migration example translates
  `lineinfile` to `line`.
- The Docker integration tests boot OpenRC in the Alpine containers, so
  the `service` examples run on Alpine too.
- The terminal recording in the README and on the docs' home page has
  larger, readable text.

### Fixed

- The icons on the docs' home page cards were shown as text.
- Links in the docs' dark color scheme were blue instead of the brand pink.

## [0.1.0] - 2026-11-01

The first release.

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
- Every command runs in the `C.UTF-8` locale, so the output sadame reads
  and guards that match text do not depend on the language of the target
  or of the SSH session.
- Examples 01 to 12, from a one-file hello to a hardened VPS, PostgreSQL,
  Docker, a multi-role inventory and an Omarchy workstation, plus Ansible
  and Itamae migration examples and CI pipelines for plan, apply and drift.
- Docker integration tests: every example on Ubuntu, Debian, Rocky, Alpine
  and Arch, on amd64 and arm64 (native runners in CI), in containers
  booting systemd; certbot against Pebble. A local-only VM layer
  (`rake vm:test`) on Ubuntu, Debian, Rocky, Arch and Omarchy VMs.
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
  each on a runner of its own architecture, before they can be published.
- `install.sh`: installs the right binary for the system after checking its
  SHA-256 checksum.
- Release workflow: a `v*` tag publishes the binaries, `SHA256SUMS` and the
  changelog section as a GitHub release.
- A Homebrew formula and an AUR package (`sadame-bin`) for the release
  binaries, generated from the release's checksums.
- Documentation at <https://enderkus.github.io/sadame/>: getting started,
  concepts, recipes and the inventory, every resource, guides, command
  line, JSON output and exit code references, and a comparison with
  Ansible, Itamae, mitamae, Chef and Puppet.

[Unreleased]: https://github.com/enderkus/sadame/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/enderkus/sadame/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/enderkus/sadame/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/enderkus/sadame/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/enderkus/sadame/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/enderkus/sadame/releases/tag/v0.1.0
