# Facts

`(facts 'name)` tells a recipe what the machine it runs on has: CPUs, memory, disk,
addresses, whether it is a virtual machine or a container. Use facts to size
configuration to the machine (worker counts, caches, buffers), to bind to
the right address, and to leave out what makes no sense in a container.
`sadame facts` shows what a recipe will see on each host.

!!! note "New in 0.3.0"

## Minimal example

```scheme
(file "/etc/demo-app/app.conf"
      #:content (string-append "workers = " (number->string (* 2 (facts 'cpus))) "\n"))
```

Templates see the same `facts`:

```text
listen ~{(facts 'ipv4)}:443;
```

## The facts

| Fact | Type | Example | Read from (Linux) |
|---|---|---|---|
| `hostname` | string | `"web1"` | `uname -n` |
| `fqdn` | string | `"web1.example.com"` | `hostname -f`; `hostname` when that fails |
| `arch` | string | `"x86_64"`, `"aarch64"` | `uname -m` |
| `kernel` | string | `"6.1.0-26-amd64"` | `uname -r` |
| `cpus` | integer | `4` | `nproc`: the CPUs sadame may run on |
| `memory-mb` | integer | `7941` | `MemTotal` in `/proc/meminfo` |
| `swap-mb` | integer | `2047` | `SwapTotal` in `/proc/meminfo` |
| `root-disk-gb` | integer | `39` | size of the file system holding `/`, from `df -Pk /` |
| `ipv4` | string or `#f` | `"203.0.113.10"` | source address of the route to the internet (`ip -4 route get`); nothing is sent |
| `default-interface` | string or `#f` | `"eth0"` | interface of that route |
| `ipv4-addresses` | list of strings | `("203.0.113.10" "10.8.0.1")` | every IPv4 address except `127.0.0.0/8` (`ip -4 -o addr show`) |
| `ipv6-addresses` | list of strings | `("2001:db8::10")` | global IPv6 addresses, from `/proc/net/if_inet6` |
| `virtualization` | string or `#f` | `"kvm"`, `"docker"` | `systemd-detect-virt`; `#f` on bare metal |
| `container` | `#t` or `#f` | `#f` | `systemd-detect-virt --container` |
| `service-manager` | string or `#f` | `"systemd"`, `"openrc"` | what the [service](../resources/service.md) resource would use |
| `machine-id` | string or `#f` | `"4c2a0f5e9b1d..."` | `/etc/machine-id`: unique per installation, never changes |

Fact names are symbols; dashes and underscores are the same, so
`(facts 'memory-mb)` and `(facts 'memory_mb)` both work. `sadame facts`
prints the underscore spelling.

Where `ip` is not installed, as in many container images, the addresses
come from `/proc/net/fib_trie` and `/proc/net/route`; where
`systemd-detect-virt` is missing, as on Alpine, `/.dockerenv`,
`/run/.containerenv` and the DMI vendor in `/sys/class/dmi/id` stand in.
For local runs on macOS, sadame reads `sysctl`, `route` and `ifconfig`;
`virtualization` and `machine-id` are `#f` there.

## How facts are read

- **When asked for.** Each fact is read the first time the recipe, or a
  template, asks for it, then kept for the run. A recipe that uses no facts
  runs no extra commands.
- **On the machine itself.** With `-h` or `-g`, the recipe runs on the
  target, so the facts are the target's. `hosts.scm` is evaluated on the
  machine running sadame and has no `facts`.
- **Never failing.** A fact that cannot be read is `#f` (an empty list for
  the address lists). Write `(or (facts 'ipv4) "127.0.0.1")` when a recipe
  must work without it.
- **Spelled right.** `(facts 'cpu)` is an error that lists every fact, so a
  typo stops `plan` instead of becoming `#f`.

Facts are read on every run, so a configuration made from them follows the
machine: after a memory upgrade, `plan` shows the new value and `drift`
reports it until it is applied.

## Seeing the facts

`sadame facts` prints what recipes see on this machine; with `-h`, `-g` or
`--limit` it connects to those hosts, as `plan` does, and prints theirs.
`--json` prints them as JSON (see [JSON output](../reference/json-output.md#facts)).

```text
--8<-- "docs/transcripts/facts-local.txt"
```

```text
--8<-- "docs/transcripts/remote-facts.txt"
```

## Scenarios

```scheme title="examples/facts/recipe.scm"
--8<-- "examples/facts/recipe.scm"
```

```text title="examples/facts/templates/motd.tmpl"
--8<-- "examples/facts/templates/motd.tmpl"
```

### Planned in a container

The container has no `/etc/machine-id`, so the minute comes from the
hostname, and `container` is true, so the kernel setting is left out:

```text
--8<-- "docs/transcripts/facts-plan.txt"
```

### Sizing PostgreSQL to the machine

`examples/05-postgres` sets `shared_buffers` to a quarter of the memory
unless vars set it:

```scheme
(define shared-buffers
  (or (vars 'shared_buffers)
      (format #f "~aMB" (quotient (facts 'memory-mb) 4))))
```

## Common mistakes

- **Facts in `hosts.scm`.** The inventory is evaluated before sadame
  connects to anything; decide per host in the recipe instead.
- **Memory and CPUs in a container.** `/proc/meminfo` in a container shows
  the host's memory, not the container's limit, and `cpus` counts the CPUs
  it may be scheduled on, which ignores CPU quotas such as Docker's
  `--cpus`. Size containers with their limits in mind.
- **Assuming an address.** A machine without a default route has no
  `ipv4`; one with several networks has several `ipv4-addresses`. Pick the
  one you mean, or set it in `vars`.
- **Using `hostname` as an ID.** Hostnames get reused and changed;
  `machine-id` stays the same for the life of the installation.

## See also

- [Recipe basics](basics.md) for `vars`, `platform` and templates.
- [Inventory](inventory.md) for per-host vars, set in `hosts.scm` rather than
  read from the machine.
