# Command line

`sadame` has five commands: `plan`, `apply` and `drift` run a recipe,
`hosts` shows which machines a selection reaches, and `facts` shows what
recipes see on them. Each takes the same
target and output options, so a command line that plans a change also
applies it after replacing `plan` with `apply`. This page lists every
command, option, environment variable and file; the
[exit codes](exit-codes.md) have their own page.

## Minimal example

```sh
sadame plan examples/01-hello     # on this machine: what would change
sadame apply examples/01-hello    # make the change
```

`sadame --help` prints the same reference in short:

```text
--8<-- "docs/transcripts/cli-help.txt"
```

## Synopsis

```text
sadame COMMAND [RECIPE] [options]
```

Options may come before or after the command and the recipe.

## Commands

| Command | Changes machines | What it does |
|---|---|---|
| `plan` | no | Reads the current state of every resource and prints what `apply` would change, as a diff. |
| `apply` | yes | Changes what differs from the recipe, in order, then runs notifications. |
| `drift` | no | Same comparison as `plan`; exits `1` when anything differs. For scripts and CI. |
| `hosts` | no | Prints the selected hosts, their connection options and vars, and where each var came from. Connects to nothing. |
| `facts` | no | Prints the [facts](../recipes/facts.md) recipes see: of this machine, or with `-h`, `-g` or `--limit`, of each selected host over SSH. Runs no recipe. |

`plan`, `apply` and `drift` are explained together in
[plan, apply, drift](../concepts/plan-apply-drift.md).

## The recipe argument

| Given | sadame runs |
|---|---|
| nothing | `./recipe.rb` |
| a file, such as `site.rb` | that file |
| a directory, such as `examples/01-hello` | `recipe.rb` in that directory |

`vars.rb` and `hosts.rb` in the recipe's directory are loaded when they
exist. Templates and files are looked up next to the recipe, then in its
`templates/` and `files/` directories. `hosts` and `facts` do not need a
recipe; given one, or a directory, they use the `hosts.rb` and `vars.rb`
next to it.

## Targets

Without any of these options, sadame runs on the machine it is started on.
With any of them, it runs on the selected hosts over SSH, copying itself
and the recipe there first (see [Remote hosts](../guides/remote-hosts.md)).

| Option | Value | Effect |
|---|---|---|
| `-h`, `--host` | `[USER@]HOST[:PORT]`, comma-separated | These hosts. A name from the inventory keeps its settings; the user and port given here win. |
| `-g`, `--group` | group names, comma-separated | The hosts of these groups in the inventory. |
| `--limit` | glob, such as `"web*"` | Only the selected hosts whose name matches (`*` any characters, `?` one). Alone, it filters every host of the inventory. |
| `--inventory` | path | Use this inventory instead of `hosts.rb` next to the recipe. |
| `--sudo` | | Run sadame with sudo on every target, whatever the inventory says. Needs passwordless sudo. Only with remote targets. |
| `--forks` | number | Work on at most this many hosts at once (default: every selected host). Only with remote targets. |
| `--serial` | number, or percentage such as `25%` | Run the hosts in batches of this size, one batch after another, in the order they were selected. When a host of a batch fails or cannot be reached, the hosts of later batches are skipped. Only with remote targets. |

`-h` and `-g` add up: `-g db -h web1.example.com` selects both.
`--limit` narrows the result. Selection rules and vars precedence are in
[Inventory](../recipes/inventory.md#selecting-hosts).

## Options

| Option | Effect |
|---|---|
| `--var KEY=VALUE` | Sets `vars[:KEY]`. Repeatable. Wins over every other source of vars. Whole numbers become Integers, `true` and `false` booleans; everything else stays a String. |
| `--vars-file PATH` | Loads more vars from a Ruby file that returns a Hash. Local runs only. |
| `--json` | Prints one JSON document instead of text; see [JSON output](json-output.md). |
| `--color` | Always use colors, even when the output is not a terminal. |
| `--no-color` | Never use colors. |
| `--host-name NAME` | `host_name` in recipes and reports for local runs (default `local`). |
| `--host-groups G,...` | `host_groups` in recipes for local runs. |
| `--version` | Prints the version. |
| `--help` | Prints the help above. |

```text
--8<-- "docs/transcripts/cli-version.txt"
```

## Environment variables

| Variable | Effect |
|---|---|
| `NO_COLOR` | When set and not empty, no colors, as with `--no-color`. |
| `SADAME_BINARY_DIR` | Push mode: copy `sadame-OS-ARCH` from this directory to targets, instead of the running binary or a download. Used with binaries built from source. |
| `SADAME_DOWNLOAD_URL` | Push mode: download target binaries and `SHA256SUMS` from this URL instead of the GitHub release of the running version. |
| `TMPDIR` | Where sadame keeps the error output of the commands it runs while they run (default `/tmp`). |

Every command sadame runs, on the machine itself or on a target, runs with
`LC_ALL=C.UTF-8`, so its output is in English whatever the system's
language (see [exec](../resources/exec.md)).

## Files

| Path | On | What |
|---|---|---|
| `recipe.rb`, `vars.rb`, `hosts.rb` | your machine | The recipe, its default vars, the inventory. |
| `templates/`, `files/` | your machine | Templates and files next to the recipe. |
| `~/.sadame/dist/VERSION/` | your machine | Target binaries downloaded for push mode. |
| `~/.sadame/bin/SHA256/sadame` | each target | The copied binary, kept between runs and reused while its checksum matches. |

Nothing else is left on a target; the copied recipe is removed after each
run. Details in [What is copied where](../guides/remote-hosts.md#what-is-copied-where).

## Scenarios

**Preview a var change on one group.** `--var` wins over `hosts.rb`, so a
change can be tried without editing anything:

```sh
sadame plan site.rb -g db --var backup_hour=4
```

**Roll out to part of a group first.** Apply to the first web server, look
at it, then apply to the rest:

```sh
sadame apply site.rb -g web --limit "web1*"
sadame apply site.rb -g web
```

**Roll out one server at a time.** With `--serial 1`, a change that breaks
the first server stops before it reaches the second; `--serial 25%` keeps
three quarters of the group untouched while the first quarter changes:

```sh
sadame apply site.rb -g web --serial 1
```

**Check one machine that is not in the inventory.** `-h` takes a full
address, so a one-off check needs no `hosts.rb`:

```sh
sadame drift examples/07-hardening-baseline -h admin@203.0.113.10:2222 --sudo
```

## Common mistakes

- **`-h` for help.** `-h` is `--host` and needs a value; use `--help`.
- **Misspelled options.** sadame stops with exit status `2` instead of
  guessing:

    ```text
    --8<-- "docs/transcripts/cli-usage-error.txt"
    ```

- **`--sudo` on a local run.** It applies to remote targets only; run
  `sudo sadame ...` on the machine itself.
- **Expecting a list from `--var`.** `--var workers=8` gives the Integer
  `8`, but `--var ports=80,443` gives the String `"80,443"`, which the
  recipe has to split.

## See also

- [Exit codes](exit-codes.md)
- [JSON output](json-output.md)
- [Inventory](../recipes/inventory.md)
- [Remote hosts](../guides/remote-hosts.md)
