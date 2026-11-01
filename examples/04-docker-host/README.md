# 04-docker-host

A Docker host: Docker Engine from Docker's package repository (Debian,
Ubuntu, Rocky) or the distribution's (Arch), log rotation for container
logs in `/etc/docker/daemon.json`, and users in the `docker` group.

**Who is this for:** anyone running containers on their own servers; and a
worked example of adding a package repository, with an `apt-get update`
that runs `:immediately` when the repository file changes.

Runs on Debian, Ubuntu, Rocky Linux and Arch Linux with systemd.

| File | Purpose |
|---|---|
| `recipe.rb` | repository, packages, daemon configuration, service, users |
| `vars.rb` | packages, users, log rotation settings |
| `files/docker-ce.repo` | Docker's repository for Rocky and RHEL |
| `templates/daemon.json.erb` | Docker daemon settings |

```sh
sudo sadame apply examples/04-docker-host
sudo sadame apply examples/04-docker-host --var log_max_size=50m   # restarts docker
```

Membership of the `docker` group gives root access through the daemon:
list only people who have root anyway.
