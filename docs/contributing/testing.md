# Testing

Sadame is tested in three layers. Each catches what the one before cannot:
the unit tests check sadame's own logic quickly and without root; the Docker
tests run every example for real on five distributions and two CPU
architectures; the VM tests run them on real machines that boot like
servers do. For every layer and every distribution an example applies to,
the rule is the same: `sadame apply` succeeds, and `sadame drift` right
after it exits `0`.

| Layer | Where | Runs | Needs |
|---|---|---|---|
| Unit | `test/unit/` | every commit, in CI, on CRuby 3.2 to 3.4 and inside the mruby build | Ruby; a C compiler for mruby |
| Docker | `test/integration/docker/`, `test/integration/push/` | every push and pull request, in CI, on amd64 and arm64 | Docker; the static binaries |
| VM | `test/integration/vm/` | by hand, on the maintainer's machines, never in CI | libvirt VMs and `hosts.local.rb` |

## Which example runs where

`test/support/example_matrix.rb` lists every example, the distributions it
supports and why it skips the others. The unit tests and the Docker tests
both read it, so they cannot disagree. Some examples only count as passing
after the VM layer, because they need a real kernel and boot to be trusted:
`03-nginx-tls-certbot` (certificates, a public endpoint),
`07-hardening-baseline` (firewall and sshd) and `12-omarchy-workstation`
(user sessions; it only runs fully on the Omarchy VM). Their READMEs say
so.

## Unit tests

```sh
bundle exec rake test:cruby   # minitest on CRuby
bundle exec rake test:mruby   # the same files with mruby-mtest, inside the mruby build
bundle exec rake test         # both
```

Resources are tested against `FakeShell` (`test/support/fake_shell.rb`),
which records the commands a resource runs and returns stubbed results, so
the tests need no root and change nothing. `FreshHostShell` stands in for a
machine where nothing is configured yet. Among the unit tests:

- every resource, including the exact command lines of each package
  manager (pacman's included);
- every example, planned and applied on a fake machine of every
  distribution the matrix lists for it, and every inventory under
  `examples/` (the cloud ones against recorded CLI output);
- the tutorials' code in `docs/contributing/architecture.md`;
- that every `examples/` path the docs mention exists.

## Docker integration tests

```sh
rake build:linux-amd64 build:linux-arm64       # the binaries under test
rake "test:docker[debian,amd64]"               # one distribution and architecture
rake "test:docker[all,arm64]"                  # every distribution, arm64
rake test:docker                               # every distribution, this machine's architecture
rake test:push                                 # push mode over SSH
```

`rake test:docker` starts one fresh container per example, from images in
`test/integration/docker/images/` built with `docker buildx`: Ubuntu 24.04,
Debian 12, Rocky Linux 9, Alpine 3.20 and Arch Linux (`archlinux:latest` on
amd64; the community image `menci/archlinuxarm` on arm64, where Arch has no
official image). The containers boot systemd as PID 1 (privileged, with the
host's cgroups), so `service` resources start and stop real units. Alpine
uses OpenRC, not systemd, so the examples with `service` resources are
skipped there, with that reason in the report. The binary under test is
`dist/sadame-linux-ARCH`, mounted unmodified.

For each example the test runs its setup (for example creating the user
that example 12 manages), then for each argument list in the matrix:
`sadame apply` must exit `0` and `sadame drift` must exit `0`.
`10-drift-demo` also runs `break-things.sh` and expects `drift` to exit `1`,
then applies again. `03-nginx-tls-certbot` gets a second container running
[Pebble](https://github.com/letsencrypt/pebble), Let's Encrypt's test
server, which accepts every challenge, so certbot really requests and
installs a certificate without a public domain.

The report lists every example as pass, fail or skip, with the reason for
each skip and the last lines of output for each failure. Results also
print one by one as examples finish.

A command that runs longer than 15 minutes (30 under emulation) is killed
and fails its example; set `SADAME_IT_TIMEOUT` in seconds to change that.
If systemd in a container has not finished booting after 3 minutes (10
under emulation), that example fails with the units systemd is still
waiting for, and the examples not yet started fail at once. To run only
some examples, set `SADAME_IT_ONLY` to text their path contains
(`SADAME_IT_ONLY=03-nginx`); `SADAME_IT_JOBS` sets how many run at once
(4 by default).

`rake test:push` is the push-mode part of this layer. It starts SSH servers
that boot systemd: three targets named like `examples/08-multi-role-inventory`'s
hosts, `db1.example.com` with sshd on port 2222, a bastion, and a host on a
network only the bastion reaches. A controller container with nothing but
the OpenSSH client then checks, among other things, `-h user@host:2222`,
`port: 2222` in `hosts.rb`, a `ProxyJump` host from a test-scoped SSH
configuration passed with `-F`, vars precedence on the targets, sudo, a
parallel run of example 08 on all three hosts, and an unreachable host.

### What arm64 coverage means

In CI, arm64 runs on x86_64 machines under QEMU, registered with
`tonistiigi/binfmt`: the arm64 binary and the arm64 distribution images,
emulated instruction by instruction. That tests the arm64 build and the
arm64 packages of each distribution, but not real arm64 hardware; there is
no arm64 VM in the VM layer yet. On an ARM64 machine (such as a Mac with
Apple silicon running Docker), `rake test:docker` runs arm64 natively.

Emulation has limits. QEMU's user mode cannot run iptables or nftables, so
`04-docker-host` (Docker's daemon) and `07-hardening-baseline` (`ufw`) are
skipped where the containers are emulated, with that reason in the report;
they run in the amd64 jobs and natively on ARM64 machines. Under Rosetta (Docker Desktop and OrbStack on Apple
silicon), an x86_64 Arch Linux container could not boot its systemd
(version 262) in our tests, so run the amd64 tests in CI or on an x86_64
machine.

### Running the Docker tests in CI

`.github/workflows/ci.yml` runs `rake "test:docker[DISTRO,ARCH]"` for all
ten combinations, plus `rake test:push`, after the build workflow has made
and verified the binaries. Each combination is its own job, so one failing
distribution does not hide the others.

## VM tests

The VM layer runs the examples on libvirt virtual machines that the
maintainer keeps at home, one per distribution: Ubuntu, Debian, Rocky, Arch
and Omarchy. It is never wired to CI: the machines and how to reach them
are private, so the details live in `test/integration/vm/hosts.local.rb`,
which git ignores. `hosts.example.rb` next to it shows the shape: one group
per distribution with the VM's address, user, port, sudo, and vars naming
its libvirt domain and clean snapshot, plus a `hypervisor` group for the
machine running libvirt.

```sh
cp test/integration/vm/hosts.example.rb test/integration/vm/hosts.local.rb   # then edit it
rake build:linux-amd64
rake "vm:reset[debian]"     # revert the debian VM to its clean snapshot (virsh over SSH)
rake "vm:test[debian]"      # reset, push every example that applies, check drift after each
rake vm:test:all            # every VM in hosts.local.rb
```

`vm:test` reverts the VM, then pushes each applicable example to it from
the machine running the tests, through the inventory, and checks that
`drift` exits `0`. `07-hardening-baseline` runs last, because it moves SSH
to port 2222, and its drift check connects to the new port. For example 03,
Pebble is started on the VM first. On the Omarchy VM only examples 01 and
12 run; example 12 runs on no other VM. Without `hosts.local.rb`, the `vm:`
tasks print what is missing and exit `0`.

## Common mistakes

- **Stale binaries.** The Docker and VM tests run whatever is in `dist/`.
  Rebuild after changing `lib/`.
- **A new example without a matrix entry.** The unit tests fail until the
  example is listed in `test/support/example_matrix.rb`, with a reason for
  each distribution it skips.
- **Testing amd64 Arch on a Mac.** See the emulation note above; use CI.

## See also

- [Building sadame](building.md)
- [Architecture](architecture.md)
