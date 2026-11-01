# 06-app-deploy-user

A user for deployments: a login shell, the team's SSH public keys in
`authorized_keys`, and a sudoers drop-in that allows restarting the
application and nothing else. The sudoers file is checked with
`visudo -cf` before it is installed.

**Who is this for:** anyone giving CI or colleagues a deploy account.

Runs on Debian, Ubuntu, Rocky Linux, Alpine (where it adds `shadow` and
`bash`) and Arch Linux.

| File | Purpose |
|---|---|
| `recipe.rb` | the user, `~/.ssh`, `authorized_keys`, the sudoers drop-in |
| `vars.rb` | user name, public keys (placeholders), allowed commands |
| `templates/authorized_keys.erb` | one line per key |
| `templates/sudoers.erb` | the sudoers rule |

```sh
sudo sadame apply examples/06-app-deploy-user
sudo -l -U deploy
```

`authorized_keys` is managed as a whole: a key added by hand shows up in
`drift` and is removed by the next `apply`.

One key or one command can also be given on the command line, which is how
[Provision a new VPS](../../docs/guides/provision-a-new-vps.md) creates an
administrator:

```sh
sadame apply examples/06-app-deploy-user -h root@203.0.113.10 \
  --var "ssh_keys=$(cat ~/.ssh/id_ed25519.pub)" --var sudo_commands=ALL
```
