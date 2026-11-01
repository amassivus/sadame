<p align="center"><img src="docs/assets/banner.png" alt="Sadame" width="720"></p>

<p align="center">
  <a href="https://github.com/enderkus/sadame/actions/workflows/ci.yml"><img src="https://github.com/enderkus/sadame/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://enderkus.github.io/sadame/"><img src="https://github.com/enderkus/sadame/actions/workflows/docs.yml/badge.svg" alt="Docs"></a>
  <a href="https://github.com/enderkus/sadame/releases/latest"><img src="https://img.shields.io/github/v/release/enderkus/sadame" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
</p>

**Sadame describes the desired state of Linux machines in plain Ruby, shows
every change as a diff before it happens, and applies it over SSH from a
single binary.**

<p align="center"><img src="docs/assets/demo.gif" alt="sadame plan, apply and drift against a server over SSH" width="820"></p>

## Install (30 seconds)

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
```

The script picks the binary for your system (Linux x86_64 or ARM64,
macOS), checks its SHA-256 checksum and installs it to `/usr/local/bin`.
The binary is about 1 MB; the machines you manage need nothing installed.

## Quickstart (60 seconds)

A recipe is plain Ruby (`examples/quickstart/recipe.rb`):

```ruby
package "nginx"
file "/var/www/html/index.html", content: "Hello from sadame\n", mode: "0644"
service "nginx", enable: true, state: :running
```

```sh
sudo sadame plan recipe.rb     # what would change, as a diff; changes nothing
sudo sadame apply recipe.rb    # change only what differs
sudo sadame drift recipe.rb    # exit 0: the machine matches; 1: it does not
```

The same recipe on a server, over SSH, with nothing to install there:

```sh
sadame apply recipe.rb -h admin@203.0.113.10 --sudo
```

For a fleet, list the servers in a `hosts.rb` and run on a group:
`sadame apply site.rb -g web`.

## Documentation

**<https://enderkus.github.io/sadame/>**: getting started, the inventory,
every resource, guides (a new VPS, an Omarchy workstation, drift in CI,
migrating from Ansible or Itamae), and twelve examples tested on Ubuntu,
Debian, Rocky Linux, Alpine and Arch.

## Compared with similar tools

| | Sadame | Ansible | Itamae | mitamae |
|---|---|---|---|---|
| Recipes in | Ruby | YAML and Jinja2 | Ruby | Ruby |
| Targets need | SSH, a shell, `tar` | SSH and Python | SSH and a shell | the binary, copied by you |
| Inventory | `hosts.rb`, in Ruby | INI or YAML, plugins | none | none |
| Dry run | `plan`, with diffs | `--check --diff` | `--dry-run` | `--dry-run` |
| Drift check for CI | `drift`, exit status 1 | no dedicated command | `--detailed-exitcode` | no |
| JSON output | `--json` | callback plugins | no | no |
| Distributed as | one static binary | Python package | Ruby gem | one binary |
| Maturity | 0.1.0, six resource types | since 2012, thousands of modules | since 2013 | since 2016 |

The [full comparison](https://enderkus.github.io/sadame/comparison/) adds
Chef and Puppet, and lists what sadame does not do yet.

## License

[MIT](LICENSE)
