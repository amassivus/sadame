<p align="center"><img src="docs/assets/banner.png" alt="Sadame" width="720"></p>

<p align="center">
  <a href="https://github.com/enderkus/sadame/actions/workflows/ci.yml"><img src="https://github.com/enderkus/sadame/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/enderkus/sadame/actions/workflows/docs.yml"><img src="https://github.com/enderkus/sadame/actions/workflows/docs.yml/badge.svg" alt="Docs"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
</p>

**Sadame describes a machine's desired state in plain Ruby, shows the
difference as a diff, and applies it, from a single binary.**

> Status: in development towards 0.1.0. `plan`, `apply` and `drift` work on
> the local machine today; `hosts.rb` inventories, pushing to remote hosts
> over SSH, and release binaries are being built.

## Install (30 seconds)

From the first release (0.1.0) on, one command installs the static binary
after checking its SHA-256 checksum:

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
```

Until then, run it from a checkout with Ruby 3.2+, or build the binary:

```sh
git clone https://github.com/enderkus/sadame.git && cd sadame
bin/sadame --version                     # run with Ruby
rake build:native                        # or build build/host/bin/sadame
```

## Quickstart (60 seconds)

```ruby
# examples/quickstart/recipe.rb
package "nginx"
file "/var/www/html/index.html", content: "Hello from sadame\n", mode: "0644"
service "nginx", enable: true, state: :running
```

```text
$ sudo bin/sadame plan examples/quickstart    # what would change, as a diff
$ sudo bin/sadame apply examples/quickstart   # change only what differs
$ sudo bin/sadame plan examples/quickstart
...
Plan: 0 to create, 0 to update, 0 to remove, 0 to run, 3 unchanged.
```

A walkthrough with real output: [Getting started](https://enderkus.github.io/sadame/getting-started/).

## Documentation

<https://enderkus.github.io/sadame/>: getting started, recipe basics, and
every resource (`package`, `file`, `directory`, `service`, `exec`, `user`)
with runnable examples from [`examples/`](examples/).

## Compared with similar tools

| | Sadame | Ansible | Itamae | mitamae |
|---|---|---|---|---|
| Recipes written in | Ruby | YAML + Jinja2 | Ruby | Ruby (Itamae-compatible) |
| Distributed as | single static binary (Linux amd64/arm64, macOS; first release: 0.1.0) | Python package | Ruby gem | single mruby binary |
| Runs on remote hosts | not yet (planned for 0.1: copies itself over `scp`, runs over `ssh`) | yes, over SSH; target needs Python | yes, commands sent over SSH | no; you copy the binary and run it on the host |
| Inventory | not yet (planned: `hosts.rb` in Ruby) | INI or YAML files, inventory plugins | none built in | none built in |
| Dry run | `sadame plan`, unified diff | `--check --diff` | `--dry-run` | `--dry-run` |
| Drift check for CI | `sadame drift`: exit 1 on difference, `--json` report | no dedicated command | no dedicated command; `--detailed-exitcode` exits 2 when resources changed | no |
| Machine-readable output | `--json` | callback plugins (e.g. `json`) | no | no |

## License

[MIT](LICENSE)
