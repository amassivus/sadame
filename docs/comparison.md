# Comparison

Sadame sits next to tools that have run servers for years. This page puts
them side by side on the questions that decide which one fits: what you
write, what the machines need, how you see changes before they happen, and
how mature each one is. Statements about the other tools describe their
documented, built-in behavior as of November 2026; plugins and commercial
add-ons can do more.

## At a glance

| | Sadame | Ansible | Itamae | mitamae | Chef Infra | Puppet |
|---|---|---|---|---|---|---|
| **Language** | Ruby, for recipes and the inventory | YAML playbooks, Jinja2 templates | Ruby | Ruby (Itamae's DSL, run by mruby) | Ruby | Puppet's own declarative language; Ruby for extensions |
| **Target requirements** | SSH, a POSIX shell, `tar`, `sha256sum` or `shasum`; Linux on x86_64 or ARM64 | SSH and Python for most modules | SSH and a shell (`itamae ssh`); Ruby for `itamae local` | the mitamae binary, which you copy there | Chef Infra Client installed (it brings its own Ruby) | Puppet agent installed (it brings its own Ruby) |
| **Agent** | none: copies itself for each run, nothing keeps running | none | none | none | Chef Infra Client, usually run on a schedule against a Chef Infra Server; local mode without a server | Puppet agent, every 30 minutes by default against a Puppet Server; `puppet apply` without one |
| **Inventory** | `hosts.rb`: groups, includes, per-host vars, dynamic by plain Ruby | INI or YAML files, inventory plugins | none; one host per `itamae ssh` run | none; runs where you start it | nodes, roles and environments on the Chef Infra Server | nodes classified on the Puppet Server; facts and reports in PuppetDB |
| **Dry run** | `sadame plan`, unified diffs | `--check --diff` | `--dry-run` | `--dry-run` | why-run mode | `--noop` |
| **Drift detection** | `sadame drift`: exit status `1` when a host differs | no dedicated command; `--check` reports what would change | no dedicated command; `--detailed-exitcode` exits `2` when resources changed | no | no dedicated command; scheduled runs correct drift | scheduled runs correct drift and mark it as a corrective change in their reports |
| **Rolling changes** | `--serial N` or `N%`: batches, stopping after a failed one | `serial:`, with `max_fail_percentage` | no; one host per `itamae ssh` run | no | no built-in; each client runs on its own schedule, optionally delayed by a random `splay` | no built-in; agents run on their own schedules, optionally with `splay` |
| **JSON output** | `--json`: one document per run, per host and resource | callback plugins, such as `ansible.posix.json` | no | no | report handlers, such as the built-in JSON file handler | run reports (YAML on the agent, JSON from PuppetDB) |
| **Single binary** | yes, about 1 MB, static on Linux | no: a Python package | no: a Ruby gem | yes, built with mruby | no: an installer package with an embedded Ruby | no: packages with an embedded Ruby |
| **Package managers** | apt, dnf, apk, pacman; the AUR through `exec` | modules for most, from apt and dnf to zypper and Homebrew | through Specinfra: apt, yum and dnf, apk, pacman, zypper and others | as Itamae, through Specinfra | built-in resources for Linux, BSD, macOS and Windows | built-in providers for Linux, BSD, macOS and Windows |
| **Maturity** | 0.2.0, November 2026: ten resource types, one maintainer | since 2012, maintained by Red Hat, thousands of modules | since 2013, community maintained | since 2016, community maintained | since 2009, maintained by Progress | since 2005, maintained by Perforce |

## Where Sadame falls short

- **Ten resource types.** `package`, `file`, `line`, `directory`, `link`,
  `service`, `exec`, `user`, `group` and `git`. No `mount`, `cron` or
  firewall resources yet; a guarded `exec` stands in for them.
- **Linux targets only.** No Windows, macOS or BSD targets, and no network
  devices.
- **No secrets management.** Nothing like Ansible Vault or Chef's
  encrypted data bags; read secrets from the environment in `vars.rb`.
- **No facts beyond the basics.** Recipes see `platform` (from
  `/etc/os-release`), `host_name` and `host_groups`, not the hardware,
  network or package facts that Ansible, Chef (Ohai) and Puppet (Facter)
  gather.
- **No ecosystem.** No Galaxy, Supermarket or Forge; recipes are shared
  as files.
- **Young.** Two releases, tested on five distributions and in CI, with
  none of the years of production use the others have.

## Where it fits

- You want the machine's state in Ruby, reviewed as a diff before it
  changes, with a yes-or-no drift answer for CI.
- The targets are Linux servers or an Arch/Omarchy workstation, and
  installing Python, Ruby or an agent on them is something you would
  rather avoid.
- The fleet fits in a `hosts.rb`: tens of machines rather than thousands,
  without a central server.

If you need Windows, a large catalog of modules, a server that keeps
machines converged on its own, or years of production history, Ansible,
Chef or Puppet are the better choice today.

## See also

- [Migrate from Ansible](guides/migrate-from-ansible.md)
- [Migrate from Itamae](guides/migrate-from-itamae.md)
- [FAQ](faq.md)
