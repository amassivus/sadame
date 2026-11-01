# Show HN

## Title

Show HN: Sadame – configuration management in plain Ruby, in one binary

(Under 80 characters. Link to https://github.com/enderkus/sadame.)

## First comment

Hi HN, I wrote Sadame because I wanted Itamae-style Ruby recipes with a
few things I kept rebuilding around other tools: a plan that shows every
change as a diff before it happens, a drift check with a useful exit
status for CI, and remote runs without installing anything on the
servers.

How it works: sadame is a static mruby binary (about 1 MB; Linux x86_64
and ARM64, macOS). Recipes run inside it. For a remote host it checks the
target's `uname`, copies the matching binary over scp into
`~/.sadame/bin/<sha256>/` (once per version), copies the recipe, and runs
it over ssh with your normal `~/.ssh/config`. Nothing stays running.

- `sadame plan` prints a unified diff per file and a summary per host.
- `sadame apply` changes only what differs, then runs notifications.
- `sadame drift` exits 1 when a host differs and 2 when it could not
  check, so a cron job or CI can tell "drifted" from "broken".
- The inventory, `hosts.rb`, is Ruby: groups, per-host vars, and dynamic
  hosts from any command's JSON output.

It is 0.1.0, and small: six resource types (package, file, directory,
service, exec, user), Linux targets only, no secrets management. The docs
have a comparison page that says where Ansible, Chef or Puppet fit better.

Testing was the part I spent most time on: every example is applied and
checked for drift in containers booting systemd on Ubuntu, Debian, Rocky,
Alpine and Arch, on both architectures, plus a local run on real VMs
before the release. That VM run found two bugs the containers could not:
sadame parsed `stat` output that was translated when the SSH session
carried a non-English `LANG`, and the hardening example locked Ubuntu
24.04 out, because sshd there is started by `ssh.socket` and kept
listening on port 22 behind the new firewall.

I would especially like to hear which resource you would need first.

Docs: https://enderkus.github.io/sadame/
