# FAQ

### What does "sadame" mean?

定め (sadame) is Japanese for what has been decided or ordained: here, the
state a machine is supposed to be in.

### Do the servers need Ruby, Python or an agent?

No. Sadame is a single static binary. In push mode it copies itself to each
target over `scp`, keyed by checksum, and runs there over `ssh`; nothing
keeps running afterwards. The targets need a POSIX shell, `tar`, and
`sha256sum` or `shasum`.

### Why Ruby for recipes, if the servers do not need Ruby?

Recipes are Ruby because a configuration language eventually needs loops,
conditions and functions; Ruby has them already, with no YAML templating on
top. The binary contains an embedded Ruby (mruby), so recipes run without a
Ruby installation anywhere.

### Can I use gems or Ruby's standard library in recipes?

No. The embedded Ruby has no `require`, no gems and no standard library
beyond what sadame includes. `JSON.parse`, `File`, `ENV` and the core
classes are available. Most recipe logic needs no more.

### Which systems are supported?

Targets: Debian, Ubuntu, Rocky Linux and other RHEL-like systems, Alpine
and Arch Linux (including Omarchy), on x86_64 and ARM64. `service` works
with systemd, and with OpenRC on Alpine. The machine running sadame can be
Linux or macOS. Windows is not supported, as a target or otherwise.

### How is this different from Ansible?

Recipes are Ruby rather than YAML, targets need no Python, `plan` shows
every change as a diff, and `drift` gives CI a yes-or-no answer. Ansible
has far more modules, a large ecosystem, Windows and network device
support, and years of production use. See
[Migrate from Ansible](guides/migrate-from-ansible.md) and the
[comparison](comparison.md).

### How is this different from Itamae and mitamae?

The recipe language is close to theirs. Sadame adds pushing to remote
hosts without installing anything, an inventory, `drift`, and JSON output;
it has fewer resources. See [Migrate from Itamae](guides/migrate-from-itamae.md).

### Is there a pull mode or an agent?

No. Sadame runs when you run it, from your machine or CI. For a periodic
check, schedule `sadame drift`; for periodic enforcement, schedule
`sadame apply`.

### How do I keep secrets out of the repository?

Read them from the environment in `vars.rb` (`ENV["DB_PASSWORD"]`), which
is evaluated on the machine running sadame, and mark files that contain
them `sensitive: true` so their diffs are hidden. There is no built-in
encryption like Ansible Vault.

### Does `apply` roll back when something fails?

No. It stops at the failing resource, leaves what was already changed in
place, and reports the rest as skipped. Fix the cause and apply again: only
what still differs is changed.

### Why does my `exec` show up in every plan?

It has no guard, so sadame cannot tell whether its work is done. Add
`creates:`, `not_if:` or `only_if:`, or `action: :nothing` if it should
only run when notified.

### Can sadame upgrade packages?

Not yet: `package` makes sure a package is installed or absent, not that
it is the newest version. Upgrade with the package manager, or with a
guarded `exec`.

### Does sadame support the AUR?

Not directly. Use an AUR helper through `exec`; see
[package](resources/package.md#aur-packages).

### How many hosts can it handle?

By default every selected host runs at the same time, each in its own
process, so the limit is your machine's processes and SSH connections.
`--forks 20` works on at most 20 at once, and `--serial` runs them in
batches that stop at the first failed one; see
[Remote hosts](guides/remote-hosts.md#many-hosts-at-once). Sadame has not
been tested on fleets of hundreds of hosts.

### Where are the logs?

Sadame prints to the terminal; with `--json` it prints a report you can
store. It writes no log files on the targets.
