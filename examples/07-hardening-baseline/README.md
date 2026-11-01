# 07-hardening-baseline

The recipe to run on every new Debian or Ubuntu VM: SSH moved to a
non-standard port with password logins and root login off, a `ufw`
firewall that only lets that port in (plus any in `open_ports`), fail2ban
watching SSH, and automatic security updates.

**Who is this for:** anyone who has just created a VPS.

Debian and Ubuntu only (`ufw` and `unattended-upgrades` are theirs).

| File | Purpose |
|---|---|
| `recipe.rb` | packages, the sshd drop-in, firewall rules, fail2ban, automatic updates |
| `vars.rb` | SSH port, extra open ports, fail2ban limits |
| `templates/sshd-hardening.conf.erb` | sshd settings, checked with `sshd -t` before they are installed |
| `templates/fail2ban-sshd.local.erb` | fail2ban's SSH jail |
| `hosts.rb` | the new server, reached on port 22 for the first run |
| `hosts-after.rb` | the same server on port 2222, for every run after that |

Make sure your user has a working SSH key and sudo before you start:
password logins are turned off.

```sh
sadame apply recipe.rb -g new                          # first run, over port 22
sadame drift recipe.rb -g new --inventory hosts-after.rb # from now on, port 2222
```

The change to make in your inventory after the first run:

```diff
-  host "vps1.example.com", user: "admin", sudo: true
+  host "vps1.example.com", user: "admin", sudo: true, port: 2222
```

The connection that runs the first apply is not cut: sshd restarts at the
end of the run, and `ufw` keeps established connections.

**Testing.** The firewall and sshd need a real kernel and boot to be
trusted, so this example only counts as passing after the VM layer (see
[Testing](../../docs/contributing/testing.md)), even though it also runs in
the Docker matrix.
