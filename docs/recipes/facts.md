# Facts

`facts` tells a recipe what the machine it runs on has: CPUs, memory, disk,
addresses, whether it is a virtual machine or a container. Use facts to size
configuration to the machine (worker counts, caches, buffers), to bind to
the right address, and to leave out what makes no sense in a container.
`sadame facts` shows what a recipe will see on each host.

!!! note "New in 0.3.0"

## Minimal example

```ruby
file "/etc/demo-app/app.conf", content: "workers = #{facts[:cpus] * 2}\n"
```

Templates see the same `facts`:

```erb
listen <%= facts[:ipv4] %>:443;
```

## The facts

| Fact | Type | Example | Read from (Linux) |
|---|---|---|---|
| `hostname` | String | `"web1"` | `uname -n` |
| `fqdn` | String | `"web1.example.com"` | `hostname -f`; `hostname` when that fails |
| `arch` | String | `"x86_64"`, `"aarch64"` | `uname -m` |
| `kernel` | String | `"6.1.0-26-amd64"` | `uname -r` |
| `cpus` | Integer | `4` | `nproc`: the CPUs sadame may run on |
| `memory_mb` | Integer | `7941` | `MemTotal` in `/proc/meminfo` |
| `swap_mb` | Integer | `2047` | `SwapTotal` in `/proc/meminfo` |
| `root_disk_gb` | Integer | `39` | size of the file system holding `/`, from `df -Pk /` |
| `ipv4` | String or nil | `"203.0.113.10"` | source address of the route to the internet (`ip -4 route get`); nothing is sent |
| `default_interface` | String or nil | `"eth0"` | interface of that route |
| `ipv4_addresses` | Array of Strings | `["203.0.113.10", "10.8.0.1"]` | every IPv4 address except `127.0.0.0/8` (`ip -4 -o addr show`) |
| `ipv6_addresses` | Array of Strings | `["2001:db8::10"]` | global IPv6 addresses, from `/proc/net/if_inet6` |
| `virtualization` | String or nil | `"kvm"`, `"docker"` | `systemd-detect-virt`; nil on bare metal |
| `container` | `true` or `false` | `false` | `systemd-detect-virt --container` |
| `service_manager` | String or nil | `"systemd"`, `"openrc"` | what the [service](../resources/service.md) resource would use |
| `machine_id` | String or nil | `"4c2a0f5e9b1d..."` | `/etc/machine-id`: unique per installation, never changes |

Where `ip` is not installed, as in many container images, the addresses
come from `/proc/net/fib_trie` and `/proc/net/route`; where
`systemd-detect-virt` is missing, as on Alpine, `/.dockerenv`,
`/run/.containerenv` and the DMI vendor in `/sys/class/dmi/id` stand in.
For local runs on macOS, sadame reads `sysctl`, `route` and `ifconfig`;
`virtualization` and `machine_id` are nil there.

## How facts are read

- **When asked for.** Each fact is read the first time the recipe, or a
  template, asks for it, then kept for the run. A recipe that uses no facts
  runs no extra commands.
- **On the machine itself.** With `-h` or `-g`, the recipe runs on the
  target, so the facts are the target's. `hosts.rb` is evaluated on the
  machine running sadame and has no `facts`.
- **Never failing.** A fact that cannot be read is nil (an empty Array for
  the address lists). Write `facts[:ipv4] || "127.0.0.1"` when a recipe
  must work without it.
- **Spelled right.** `facts[:cpu]` is an error that lists every fact, so a
  typo stops `plan` instead of becoming nil.

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

```ruby title="examples/facts/recipe.rb"
--8<-- "examples/facts/recipe.rb"
```

```erb title="examples/facts/templates/motd.erb"
--8<-- "examples/facts/templates/motd.erb"
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

```ruby
shared_buffers = vars[:shared_buffers] || "#{facts[:memory_mb] / 4}MB"
```

## Common mistakes

- **Facts in `hosts.rb`.** The inventory is evaluated before sadame
  connects to anything; decide per host in the recipe instead.
- **Memory and CPUs in a container.** `/proc/meminfo` in a container shows
  the host's memory, not the container's limit, and `cpus` counts the CPUs
  it may be scheduled on, which ignores CPU quotas such as Docker's
  `--cpus`. Size containers with their limits in mind.
- **Assuming an address.** A machine without a default route has no
  `ipv4`; one with several networks has several `ipv4_addresses`. Pick the
  one you mean, or set it in `vars`.
- **Using `hostname` as an ID.** Hostnames get reused and changed;
  `machine_id` stays the same for the life of the installation.

## See also

- [Recipe basics](basics.md) for `vars`, `platform` and templates.
- [Inventory](inventory.md) for per-host vars, set in `hosts.rb` rather than
  read from the machine.
