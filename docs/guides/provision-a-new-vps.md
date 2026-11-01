# Provision a new VPS

This guide takes a freshly created cloud server, the kind Hetzner Cloud or
DigitalOcean hands you with only `root` and your SSH key, to a hardened web
server in three `sadame apply` runs: an administrator account, a security
baseline (SSH on port 2222 with keys only, a firewall, fail2ban, automatic
updates) and nginx serving a site. Each step is one of the examples, used as
it is, and the output below comes from running exactly these commands
against a fresh Debian 12 server.

## What you need

- sadame on your machine (see [Install](../install.md)) and a checkout of
  the repository for the examples, or copies of `examples/06-app-deploy-user`,
  `examples/07-hardening-baseline` and `examples/02-nginx-static-site`;
- an SSH key pair; the commands below use `~/.ssh/id_ed25519.pub`;
- a new server running Debian 12 or Ubuntu 24.04, reachable as `root` with
  that key.

## 1. Create the server

Create it with your public key, in the web console or with the provider's
CLI. With Hetzner Cloud's `hcloud`, after `hcloud ssh-key create --name me
--public-key-from-file ~/.ssh/id_ed25519.pub`:

```sh
hcloud server create --name vps1 --type cx22 --image debian-12 --ssh-key me   # types: hcloud server-type list
```

With DigitalOcean's `doctl`, using the fingerprint from
`doctl compute ssh-key list`:

```sh
doctl compute droplet create vps1 --image debian-12-x64 --size s-1vcpu-1gb --region fra1 --ssh-keys FINGERPRINT
```

Note the server's IP address; the commands below write
`vps1.example.com` in its place. Connect once with `ssh root@ADDRESS` to
check the key works and to accept the host key.

## 2. An administrator instead of root

`06-app-deploy-user` creates a user with your key and a sudoers rule.
Given `ALL` as its only command, the user is an administrator with
passwordless sudo, which sadame needs:

```text
--8<-- "docs/transcripts/vps-admin-user.txt"
```

The first run copied sadame to the server (`~/.sadame/bin/`); later runs
reuse it.

## 3. The security baseline

From now on, connect as `deploy` with `--sudo`. `07-hardening-baseline`
moves SSH to port 2222, turns off root and password logins, and lets only
SSH and the ports in `open_ports` through the firewall:

```text
--8<-- "docs/transcripts/vps-hardening.txt"
```

sshd restarted on the new port at the end of the run; the connection that
ran it was kept, because `ufw` lets established connections through. On
Ubuntu, where systemd starts sshd from `ssh.socket`, the recipe also moves
the socket to the new port; restarting sshd alone would leave it on 22,
behind the firewall.

## 4. The web server

From now on, the server is at port 2222:

```text
--8<-- "docs/transcripts/vps-web.txt"
```

## 5. Check the result

`drift` on the baseline exits `0`: everything is as the recipe says. Root
can no longer log in, and port 22 no longer answers:

```text
--8<-- "docs/transcripts/vps-check.txt"
```

## Keep it in an inventory

Typing `-h deploy@...:2222 --sudo` gets old. Put the server in a
`hosts.rb`, as `examples/07-hardening-baseline/hosts-after.rb` does, and
use `-g`:

```ruby title="examples/07-hardening-baseline/hosts-after.rb"
--8<-- "examples/07-hardening-baseline/hosts-after.rb"
```

Then [Drift in CI](drift-in-ci.md) checks the server every morning.

## Common mistakes

- **Running the baseline before the administrator account.** The baseline
  turns off root login; without another user with a key and sudo, you are
  locked out.
- **Forgetting `open_ports`.** The firewall only lets SSH in. A web server
  needs `--var open_ports=80,443` (or `open_ports: [80, 443]` in
  `vars.rb`).
- **Connecting to port 22 after the baseline.** Use `HOST:2222`, `port:
  2222` in `hosts.rb`, or `Port 2222` in `~/.ssh/config`.
- **The provider's own firewall.** Hetzner and DigitalOcean also have
  firewalls outside the server; open ports 2222, 80 and 443 there too if
  you use them.

## See also

- [Remote hosts](remote-hosts.md): SSH options, sudo and troubleshooting.
- [Examples](../examples/index.md): `06`, `07` and `02`.
