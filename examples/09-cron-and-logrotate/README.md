# 09-cron-and-logrotate

An application's scheduled jobs in `/etc/cron.d/app` and its log rotation
in `/etc/logrotate.d/app`, both generated from vars with `file` resources.
The logrotate file is checked with `logrotate -d` before it is installed.

**Who is this for:** anyone with jobs in a crontab nobody remembers
editing; and an example of replacing hand-edited system files with
templates.

Runs on Debian, Ubuntu, Rocky Linux and Arch Linux with systemd.

| File | Purpose |
|---|---|
| `recipe.rb` | cron and logrotate, the application user and directories, the two files |
| `vars.rb` | the jobs and how many days of logs to keep |
| `templates/cron.erb` | `/etc/cron.d/app`, one line per job |
| `templates/logrotate.erb` | `/etc/logrotate.d/app` |

```sh
sudo sadame apply examples/09-cron-and-logrotate
sudo sadame plan examples/09-cron-and-logrotate --var rotate_days=30
```
