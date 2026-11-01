# 05-postgres

PostgreSQL with `max_connections`, `work_mem` and `listen_addresses` set
from vars, and `shared_buffers` a quarter of the machine's memory
(`facts[:memory_mb]`) unless vars set it. The settings go into
`conf.d/tuning.conf`, so the distribution's own `postgresql.conf` is not
rewritten, and PostgreSQL restarts when they change.

**Who is this for:** anyone running a PostgreSQL server; and an example of
handling differences between distributions in plain Ruby: Debian and Ubuntu
create and start a cluster on install, Rocky and Arch need `initdb` first.

Runs on Debian, Ubuntu, Rocky Linux and Arch Linux with systemd.

| File | Purpose |
|---|---|
| `recipe.rb` | package, cluster creation where needed, `conf.d`, service |
| `vars.rb` | the settings, and the PostgreSQL version Debian and Ubuntu install |
| `templates/tuning.conf.erb` | the settings file |

```sh
sudo sadame apply examples/05-postgres
sudo sadame plan examples/05-postgres --var shared_buffers=1GB   # shows the change and the restart
```
