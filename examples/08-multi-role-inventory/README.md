# 08-multi-role-inventory

One recipe for three servers in two roles, chosen by the groups in
`hosts.rb`. Used on the [Inventory](../../docs/recipes/inventory.md) and
[Remote hosts](../../docs/guides/remote-hosts.md) pages.

**Who is this for:** teams managing several servers with different jobs.

| File | Purpose |
|---|---|
| `hosts.rb` | groups `web` (web1, web2), `db` (db1, sshd on port 2222) and `all` |
| `vars.rb` | defaults, overridden per group and host in `hosts.rb` |
| `site.rb` | the base for every host, then `roles/web` or `roles/db` by group |
| `roles/web.rb` | nginx, an app config with a worker count, the service |
| `roles/db.rb` | SQLite, a system user, a nightly dump in `/etc/cron.d` |

The host names are placeholders. Replace them, or map them to real
machines in `~/.ssh/config`. The `deploy` user needs passwordless sudo, and
the hosts need Debian or Ubuntu and systemd.

```sh
cd examples/08-multi-role-inventory
sadame hosts                                  # every host, its connection and vars
sadame plan site.rb -g web                    # the web servers
sadame apply site.rb -g all                   # all three, in parallel
sadame drift site.rb --limit "web*"           # hosts whose name starts with web
sadame plan site.rb -h deploy@db1.example.com:2222
```
