# Sadame 0.1.0: configuration management in plain Ruby, in one binary

Sadame 0.1.0 is out. It is a configuration management tool: you describe
the state a Linux machine should be in, as a Ruby recipe, and sadame makes
the machine match.

```ruby
package "nginx"
file "/var/www/html/index.html", content: "Hello from sadame\n", mode: "0644"
service "nginx", enable: true, state: :running
```

Three commands work on a recipe. `sadame plan` reads the machine and prints
what would change, with a unified diff for every file. `sadame apply`
changes only what differs, then runs the notifications that changes
triggered, such as an nginx reload. `sadame drift` compares like `plan`
and exits with status 1 when anything differs, so a scheduled CI job can
tell you that a server was changed by hand.

Sadame is a single static binary of about 1 MB, built with mruby, for Linux
on x86_64 and ARM64 and for macOS. Recipes run inside it, so the machines
need no Ruby, Python or agent. To manage a server, name it on the command
line or in a `hosts.rb` inventory; sadame copies itself there over `scp`,
keyed by checksum, runs over `ssh`, and leaves nothing running. Your
`~/.ssh/config` applies: ports, keys, jump hosts.

```sh
sadame apply site.rb -g web --limit "web1*"
```

The inventory is Ruby as well: groups, per-host vars, and code where other
tools need plugins, such as building hosts from a cloud CLI's JSON.

What 0.1.0 has:

- six resource types: `package` (apt, dnf, apk, pacman), `file` (with
  templates and a `verify:` command), `directory`, `service` (systemd),
  `exec` (with guards) and `user`;
- notifications, delayed or immediate;
- `--json` reports for every command;
- twelve examples, from a one-file hello to a hardened VPS, PostgreSQL and
  an Omarchy workstation, each applied and checked for drift on Ubuntu,
  Debian, Rocky Linux, Alpine and Arch, on both architectures, in CI.

What it does not have yet: more resource types (`cron`, `group`, `link`,
`mount`), Windows or macOS targets, secrets management, and years of
production use. The documentation has a plain comparison with Ansible,
Itamae, mitamae, Chef and Puppet, including where those are the better
choice.

Install:

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
```

Documentation: https://enderkus.github.io/sadame/
Source, MIT licensed: https://github.com/enderkus/sadame

Bug reports and proposals for new resources are welcome; the issue
templates ask for what makes them quick to act on.
