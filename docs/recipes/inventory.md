# Inventory

An inventory lists the machines a recipe runs on, groups them, and gives
groups and hosts their own vars and connection options. It is a file named
`hosts.rb` next to the recipe (or any file passed with `--inventory`), and
like a recipe it is plain Ruby: a static list is a few `host` lines, and a
dynamic inventory is code that calls `host` in a loop over data from a
file or a cloud provider's CLI. There is no plugin system to learn.

## Minimal example

```ruby title="examples/08-multi-role-inventory/hosts.rb"
--8<-- "examples/08-multi-role-inventory/hosts.rb"
```

`sadame hosts` shows what sadame makes of it: every host, how it will be
reached, and each var with the layer it came from:

```text
--8<-- "docs/transcripts/inventory-hosts.txt"
```

## The hosts.rb language

| Method | Where | Meaning |
|---|---|---|
| `group :name do ... end` | top level | Declares a group, or adds to one declared earlier. Groups cannot be nested. |
| `group :name, include: [:a, :b]` | top level | The group also contains every host of groups `a` and `b`. The block is optional. |
| `host "name", options` | in a group, or top level for an ungrouped host | Declares a host. A host may appear in several groups. |
| `vars key: value, ...` | in a group | Vars for every host of the group. |
| `command_output("command")` | anywhere | Runs a command on the machine running sadame and returns its output; fails when the command fails. |

`JSON.parse` and `File.read` are available, as in recipes.

Options of `host`:

| Option | Type | Default | Meaning |
|---|---|---|---|
| `address` | String | the host's name | Address to connect to, when the name is only a label. |
| `user` | String | ssh's default (`~/.ssh/config` or your user name) | User to log in as. |
| `port` | Integer | ssh's default (`~/.ssh/config` or 22) | SSH port. |
| `sudo` | `true` or `false` | `false` | Run sadame with `sudo` on this host. |
| `ssh_opts` | Array of Strings | `[]` | Extra options for `ssh` and `scp`, such as `["-i", "~/.ssh/deploy"]` or `["-F", "ssh_config"]`. |
| `vars` | Hash | `{}` | Vars for this host only. |

Connection options may be given in any one declaration of a host. Giving
the same option two different values is an error; vars from several
declarations are merged.

## Vars precedence

Every target gets one `vars` Hash, merged from these layers. A higher layer
wins for the same key:

| Precedence | Layer | Shown by `sadame hosts` as |
|---|---|---|
| 1 (highest) | `--var key=value` on the command line | `--var` |
| 2 | `vars:` of the `host` | `host` |
| 3 | `vars` of the host's groups; a group overrides the groups it includes, and otherwise a group declared later overrides one declared earlier | `group NAME` |
| 4 (lowest) | `vars.rb` next to the recipe | `vars.rb` |

In the example, `workers` is 2 in `vars.rb`, 4 for the `web` group and 8
for `web2`; `env` is `"staging"` in `vars.rb` but `"production"` from
`all`, which includes `web` and `db`. `--var` overrides all of them:

```text
--8<-- "docs/transcripts/inventory-hosts-var.txt"
```

## Selecting hosts

Without `-h`, `-g` or `--limit`, sadame runs on the machine it is started
on. With any of them, it runs on the selected hosts over SSH (see
[Remote hosts](../guides/remote-hosts.md)).

| Flag | Selects |
|---|---|
| `-g web,db` | the hosts of these groups, including groups they include |
| `-h web1.example.com,admin@db9.example.com:2200` | these hosts; a name found in the inventory keeps its options, with `user` and `port` from the flag when given; any other name works too |
| `--limit "web*"` | only the selected hosts whose name matches the pattern (`*` any characters, `?` one); alone, it filters every host of the inventory |

Flags combine: `-g db -h web1.example.com` selects both, and
`-g all --limit "web*"` narrows `all` down to the web servers. Hosts are
taken in the order of the groups given, then the `-h` hosts; each runs once.
`sadame hosts` accepts the same flags, which makes it the way to check a
selection before running anything.

## Using groups in recipes

A recipe learns the groups of the host it runs on from `host_groups`, a
list of symbols that includes groups reached through `include:`. The
example's `site.rb` picks roles that way:

```ruby title="examples/08-multi-role-inventory/site.rb"
--8<-- "examples/08-multi-role-inventory/site.rb"
```

`host_name` is the host's name from the inventory or `-h`. For local runs
they are `"local"` and `[]`, unless set with `--host-name` and
`--host-groups`, which is a way to try a role on a test machine:

```sh
sudo sadame plan site.rb --host-groups web,all
```

## Dynamic inventories

### From a file

```ruby title="examples/11-dynamic-inventory/hosts.rb"
--8<-- "examples/11-dynamic-inventory/hosts.rb"
```

```json title="examples/11-dynamic-inventory/servers.json"
--8<-- "examples/11-dynamic-inventory/servers.json"
```

```text
--8<-- "docs/transcripts/inventory-dynamic.txt"
```

### From a cloud provider's CLI

`command_output` runs the provider's CLI on the machine running sadame,
with whatever login that CLI already has. These three files are in the
example directory; pass one with `--inventory`.

=== "Hetzner Cloud (hcloud)"

    ```ruby title="examples/11-dynamic-inventory/hosts-hcloud.rb"
    --8<-- "examples/11-dynamic-inventory/hosts-hcloud.rb"
    ```

=== "DigitalOcean (doctl)"

    ```ruby title="examples/11-dynamic-inventory/hosts-doctl.rb"
    --8<-- "examples/11-dynamic-inventory/hosts-doctl.rb"
    ```

=== "AWS (aws)"

    ```ruby title="examples/11-dynamic-inventory/hosts-aws.rb"
    --8<-- "examples/11-dynamic-inventory/hosts-aws.rb"
    ```

The tests run each of them against recorded CLI output, so a change in
sadame that breaks them is noticed. A change in a CLI's output format is
not; check `sadame hosts --inventory ...` after upgrading the CLI.

## Common mistakes

- **Relative paths in hosts.rb.** `File.read("servers.json")` is relative
  to the directory you run sadame from. Build paths from
  `File.dirname(__FILE__)`, as the example does.
- **`vars` outside a group.** Top-level `vars` is an error; use `vars.rb`
  for defaults and `host ..., vars: {}` for one host.
- **Expecting `-g all` without a group named `all`.** Groups are only what
  `hosts.rb` declares. `sadame hosts` without flags lists every host.
- **Slow commands in a dynamic inventory.** `command_output` runs every
  time the inventory loads, including for `plan`. Cache the result in a
  file if the CLI is slow.
- **Secrets in hosts.rb.** It is evaluated on the machine running sadame,
  and its vars are sent to the targets. Read secrets from the environment
  (`ENV["DB_PASSWORD"]`) rather than committing them.
- **Facts in hosts.rb.** For the same reason, `hosts.rb` cannot see what a
  machine has. Read [facts](facts.md) in the recipe, which runs on the
  target, and keep in `hosts.rb` what you decide.

## See also

- [Remote hosts](../guides/remote-hosts.md): how sadame connects, sudo,
  jump hosts and troubleshooting.
- [Recipe basics](basics.md): vars and `include_recipe`.
