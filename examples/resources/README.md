# Resource examples

One small, runnable recipe per resource, used by the pages under
[docs/resources](../../docs/resources/). Each converges: after one
`apply`, `plan` reports nothing to change.

| Directory | Page | Needs |
|---|---|---|
| `package/` | [package](../../docs/resources/package.md) | root; apt, dnf, apk or pacman |
| `file/` | [file](../../docs/resources/file.md) | root (writes under `/etc` and `/usr/local/bin`) |
| `directory/` | [directory](../../docs/resources/directory.md) | root; a `www-data` user (Debian/Ubuntu) |
| `line/` | [line](../../docs/resources/line.md) | root; installs the SSH server |
| `link/` | [link](../../docs/resources/link.md) | root (writes under `/srv` and `/usr/local/bin`) |
| `service/` | [service](../../docs/resources/service.md) | root; systemd, or OpenRC on Alpine |
| `exec/` | [exec](../../docs/resources/exec.md) | root |
| `user/` | [user](../../docs/resources/user.md) | root; Linux with `useradd` |
| `group/` | [group](../../docs/resources/group.md) | root; Linux |
| `git/` | [git](../../docs/resources/git.md) | root; network access to GitHub |
