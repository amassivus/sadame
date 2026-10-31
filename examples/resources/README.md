# Resource examples

One small, runnable recipe per resource, used by the pages under
[docs/resources](../../docs/resources/). Each converges: after one
`apply`, `plan` reports nothing to change.

| Directory | Page | Needs |
|---|---|---|
| `package/` | [package](../../docs/resources/package.md) | root; apt, dnf, apk or pacman |
| `file/` | [file](../../docs/resources/file.md) | root (writes under `/etc` and `/usr/local/bin`) |
| `directory/` | [directory](../../docs/resources/directory.md) | root; a `www-data` user (Debian/Ubuntu) |
| `service/` | [service](../../docs/resources/service.md) | root; systemd; Arch (nginx is not started on install there) |
| `exec/` | [exec](../../docs/resources/exec.md) | root |
| `user/` | [user](../../docs/resources/user.md) | root; Linux with `useradd` |
