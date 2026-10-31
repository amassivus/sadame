# Remote hosts

With `-h`, `-g` or `--limit`, sadame runs a recipe on other machines over
SSH. Nothing has to be installed on them first: sadame copies its own
binary and the recipe with your system's `scp`, runs it with `ssh`, and
shows each host's output as it arrives, prefixed with the host's name. This
guide covers how hosts are named and reached, what is copied where, sudo,
jump hosts, running many hosts at once, and what to do when a connection
fails.

## Quick example

```sh
cd examples/08-multi-role-inventory
sadame plan site.rb -h deploy@db1.example.com:2222
```

```text
--8<-- "docs/transcripts/remote-host-flag.txt"
```

The targets need a POSIX shell, `tar` with gzip support, `sha256sum` (or
`shasum`), and Linux or macOS on x86_64 or ARM64. The machine running
sadame needs the OpenSSH client (`ssh` and `scp`).

## Naming a host: `[user@]host[:port]`

| Form | Meaning |
|---|---|
| `web1.example.com` | user and port from `~/.ssh/config`, or ssh's defaults |
| `deploy@web1.example.com` | log in as `deploy` |
| `db1.example.com:2222` | connect to port 2222 |
| `admin@db1.example.com:2222` | both |
| `root@[2001:db8::1]:22` | IPv6 addresses go in brackets |

A name that is also in the inventory keeps the options from there; the
user and port given with `-h` replace those. Several hosts are separated by
commas: `-h web1.example.com,web2.example.com`.

## SSH configuration and keys

Sadame runs the system's `ssh` and `scp`, so everything in `~/.ssh/config`
applies: `HostName`, `User`, `Port`, `IdentityFile`, `ProxyJump`, and the
SSH agent. It adds these options to every connection:

| Option | Why |
|---|---|
| `-o BatchMode=yes` | never stop to ask for a password; use keys or an agent |
| `-o ConnectTimeout=10` | an unreachable host fails after 10 seconds |
| `-o ControlMaster=auto`, `ControlPath`, `ControlPersist=60` | the several commands of a push share one connection |

A host's `ssh_opts` from `hosts.rb` come before them, so they can override
them; ssh uses the first value it sees for an option. They are passed to
`scp` too, so use options both accept, such as `-i`, `-F`, `-J` and `-o`.

The first connection to a new host checks its host key against
`~/.ssh/known_hosts` as usual. With `BatchMode`, an unknown key is not
accepted interactively: connect once with `ssh` yourself, add the key with
`ssh-keyscan`, or set `StrictHostKeyChecking accept-new` for those hosts in
`~/.ssh/config`.

## Non-standard ports

Any of these works; `hosts.rb` is the usual place, as for `db1` in
`examples/08-multi-role-inventory/hosts.rb`:

```ruby
host "db1.example.com", port: 2222    # in hosts.rb
```

```sh
sadame plan site.rb -h db1.example.com:2222
```

```text
Host db1.example.com                  # in ~/.ssh/config
  Port 2222
```

ssh takes the port with `-p` and scp with `-P`; sadame passes the right
one to each.

## Jump hosts

A host that is only reachable through a bastion needs one `ProxyJump` line
in `~/.ssh/config`; nothing in sadame changes:

```text
Host app1.internal
  User deploy
  ProxyJump bastion.example.com
```

To keep that configuration with the recipe instead, put it in a file and
pass it with `-F` through `ssh_opts`. With `-F`, ssh reads only that file,
so it must also name the key and known hosts file:

```ruby
host "app1.internal", ssh_opts: ["-F", "ssh_config"]
```

Sadame's own tests reach a host on a private network through a bastion this
way; see `test/integration/push/ssh_config` and the `internal` group in
`test/integration/push/recipe/hosts.rb`.

## sudo

Most recipes need root on the target. Log in as a user with sudo rights and
let sadame use `sudo`, either per host or for every target of a run:

```ruby
host "web1.example.com", user: "deploy", sudo: true    # in hosts.rb
```

```sh
sadame apply site.rb -g web --sudo                    # every selected host
```

sudo must not ask for a password, because there is no terminal to type it
into. Sadame checks that with `sudo -n true` before it copies anything. A
line like this in `/etc/sudoers.d/deploy` (edit it with `visudo -f`) gives
the `deploy` user passwordless sudo:

```text
deploy ALL=(ALL) NOPASSWD: ALL
```

## What is copied where

| What | Where | When |
|---|---|---|
| The sadame binary for the target's system | `~/.sadame/bin/SHA256/sadame` on the target | only when that checksum is not there yet; it is checked after copying |
| The recipe's directory, without `.git`, `vars.rb` and `hosts.rb` | `~/.sadame/run/RUN_ID/` on the target | every run; removed when sadame finishes there |
| The target's vars, already merged | `~/.sadame/run/RUN_ID/.sadame-vars.rb` | every run; removed with the directory |
| Binaries downloaded for other systems | `~/.sadame/dist/VERSION/` on the machine running sadame | the first time a system is needed |

`vars.rb` and `hosts.rb` are evaluated on the machine running sadame, so
`ENV` and files they read are those of that machine. The target receives
the result. Templates and the recipe itself run on the target.

To clean a target, remove `~/.sadame`.

## Where the binary comes from

Sadame needs a binary for each target's system (`uname -sm` on the
target). It looks in this order:

1. `$SADAME_BINARY_DIR/sadame-linux-amd64` (and so on), if that variable is
   set; useful for development builds and machines without internet
   access: `SADAME_BINARY_DIR=dist`;
2. itself, when it is the binary for that system (a Linux x86_64 machine
   pushing to Linux x86_64 targets copies itself);
3. `~/.sadame/dist/VERSION/`, from an earlier download;
4. the GitHub release of the same version, checked against its
   `SHA256SUMS`; `$SADAME_DOWNLOAD_URL` points at a mirror instead.

## Many hosts at once

Every selected host runs at the same time, in its own process. Lines from
different hosts interleave, each with its host's name in front, and a table
at the end shows each host's result:

```text
--8<-- "docs/transcripts/remote-drift-limit.txt"
```

| Result | Meaning | Counts as exit status |
|---|---|---|
| `ok` | sadame finished with status 0 | 0 |
| `drift` | `drift` found a difference | 1 |
| `failed` | `apply` had a failed resource | 1 |
| `error` | sadame could not run, or exited with 2 | 2 |
| `unreachable` | ssh could not connect | 2 |

The exit status of the whole run is the highest of its hosts. A host that
cannot be reached does not stop the others:

```text
--8<-- "docs/transcripts/remote-unreachable.txt"
```

??? example "Full output of `sadame apply site.rb -g all` on three fresh servers"

    ```text
    --8<-- "docs/transcripts/remote-apply-all.txt"
    ```

With `--json`, the run prints one document with each host's result and its
full report; see [JSON output](../reference/json-output.md#push-mode).

## Troubleshooting

| Symptom in the summary | Cause | Fix |
|---|---|---|
| `connect failed: USER@HOST: Permission denied (publickey).` | no key the server accepts for that user | check the user name; `ssh-copy-id USER@HOST`; set `IdentityFile` or `ssh_opts: ["-i", "..."]` |
| `connect failed: Host key verification failed.` | the host's key is unknown or changed | if the change is expected, `ssh-keygen -R HOST` and connect once; if not, find out why first |
| `connect failed: ssh: connect to host HOST port 22: Connection refused` | wrong port, or sshd not running | give the port: `HOST:2222`, `port: 2222` or `Port` in `~/.ssh/config` |
| `connect failed: ssh: Could not resolve hostname HOST` | DNS or a typo | check the name; set `address:` in `hosts.rb` or `HostName` in `~/.ssh/config` |
| `sudo failed: sudo: a password is required` | sudo asks for a password | give the user passwordless sudo, or run without `sudo` |
| `/PATH/sadame-linux-arm64 does not exist (SADAME_BINARY_DIR is set)` or `no sadame-linux-arm64 for this development version` | no binary for the target's system | build it (`rake build:linux-arm64`) or use a released version |
| `sadame has no binary for Linux riscv64` | the target's CPU is not supported | run sadame from source on that machine |

The first three, as sadame reports them:

```text
--8<-- "docs/transcripts/trouble-permission-denied.txt"
```

```text
--8<-- "docs/transcripts/trouble-host-key.txt"
```

```text
--8<-- "docs/transcripts/trouble-wrong-port.txt"
```

And a user whose sudo asks for a password:

```text
--8<-- "docs/transcripts/trouble-sudo-password.txt"
```

## Common mistakes

- **Expecting password prompts.** Sadame never asks for SSH or sudo
  passwords. Use keys and passwordless sudo.
- **Recipes in a large directory.** The recipe's whole directory is copied
  to every host on every run. Keep recipes in their own directory, not at
  the top of a large repository.
- **Reading local files in a recipe.** A recipe runs on the target; a path
  like `~/.ssh/id_rsa.pub` there means the target's file. Put files the
  recipe needs next to it and use `source:`.
- **Pushing to a target with a different sadame version installed.** That
  does not matter: sadame always runs the binary it copied, identified by
  its checksum.

## See also

- [Inventory](../recipes/inventory.md): groups, vars and selecting hosts.
- [Drift in CI](drift-in-ci.md): checking hosts on a schedule.
