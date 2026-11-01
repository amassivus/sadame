# Examples

Every example is a directory under
[`examples/`](https://github.com/enderkus/sadame/tree/main/examples) with a
README, its recipe, and the templates, vars and inventory it needs. All of
them are applied and checked for drift in the Docker tests on every
distribution they support (see [Testing](../contributing/testing.md)), so
they work as shown.

| Example | What it does | Who is this for | Runs on |
|---|---|---|---|
| `01-hello` | one file in `/tmp`, the smallest recipe | anyone trying sadame for the first time | everywhere, no root needed |
| `02-nginx-static-site` | nginx, its configuration from templates, a page, reload on change | a first real server recipe | Debian, Ubuntu, Rocky, Arch |
| `03-nginx-tls-certbot` | HTTPS with Let's Encrypt; the certificate is requested once by a guarded `exec` | anyone putting a site on the internet | Debian, Ubuntu, Rocky, Arch; counts after the VM layer |
| `04-docker-host` | Docker Engine from Docker's repository, log rotation, users in the `docker` group | anyone running containers on their own servers | Debian, Ubuntu, Rocky, Arch |
| `05-postgres` | PostgreSQL with settings tuned through vars, `shared_buffers` sized from the machine's memory | anyone running a PostgreSQL server | Debian, Ubuntu, Rocky, Arch |
| `06-app-deploy-user` | a deploy user, SSH keys, a sudoers drop-in checked by `visudo` | anyone giving CI or colleagues a deploy account | Debian, Ubuntu, Rocky, Alpine, Arch |
| `07-hardening-baseline` | SSH on port 2222, `ufw`, fail2ban, automatic updates | anyone who has just created a VPS | Debian, Ubuntu; counts after the VM layer |
| `08-multi-role-inventory` | three servers, two roles chosen by `hosts.rb` groups | teams with several servers doing different jobs | Debian, Ubuntu |
| `09-cron-and-logrotate` | scheduled jobs and log rotation as plain files | anyone with jobs in a crontab nobody remembers editing | Debian, Ubuntu, Rocky, Arch |
| `10-drift-demo` | a recipe and a script that breaks the machine, to watch `drift` catch it | anyone deciding how to use `drift` | Debian, Ubuntu |
| `11-dynamic-inventory` | `hosts.rb` built from a JSON file, Hetzner Cloud, DigitalOcean or AWS | anyone whose server list lives somewhere else | everywhere |
| `12-omarchy-workstation` | a personal Arch or Omarchy laptop: packages, dotfiles, a user timer, an AUR package | Omarchy and Arch users | Arch, Omarchy; counts after the VM layer |

Besides these, the documentation's own examples live in `examples/basics`,
`examples/quickstart`, `examples/notifications`, `examples/facts`,
`examples/resources/` and `examples/ci/`; each page shows the ones it uses.

## Where to go from here

- New to sadame: `01-hello`, then [Getting started](../getting-started.md).
- A server: `07-hardening-baseline`, then `02` or `03`; see
  [Provision a new VPS](../guides/provision-a-new-vps.md).
- Several servers: `08-multi-role-inventory` and
  [Inventory](../recipes/inventory.md).
- A laptop: `12-omarchy-workstation` and
  [Omarchy workstation](../guides/omarchy-workstation.md).
