# exec

`exec` runs a shell command. It is the escape hatch for anything the other
resources do not cover: issuing a certificate, running an installer,
installing from the AUR. A command has no state sadame can read, so to stay
idempotent an `exec` needs a guard that says when the work is already done.
Guards are evaluated during `plan` as well as `apply`; the command itself
only runs during `apply`.

## Minimal example

```ruby title="examples/resources/exec/minimal.rb"
--8<-- "examples/resources/exec/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `command` | String | the resource name | Command to run, when you want the name to be a short label. |
| `creates` | String | none | Skip when this path exists. |
| `not_if` | String | none | Skip when this command exits 0. |
| `only_if` | String | none | Skip unless this command exits 0. |
| `cwd` | String | inherited | Working directory for the command and its guards. |
| `env` | Hash of String to String | none | Environment variables for the command and its guards. |
| `action` | `:run` or `:nothing` | `:run` | `:nothing` never runs the command on its own, only when another resource notifies it. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this command runs. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

The command runs when every guard you gave agrees: the `creates` path is
missing, `not_if` exits non-zero, and `only_if` exits 0. Guards are checked
in that order and checking stops at the first one that says skip. Without
any guard, the command runs on every `apply`.

Commands and guards run with `/bin/sh` and standard input closed. A command
that exits non-zero fails the resource: `apply` prints the exit status and
the command's error output, marks the resource `failed`, and skips the
resources after it.

Every command sadame runs, including yours, runs in the `C.UTF-8` locale
(`LC_ALL=C.UTF-8`, `LANGUAGE` unset), so programs answer in English
whatever the language of the machine or of the SSH session: a guard such as
`not_if: "ufw status | grep -q 'Status: active'"` matches on every system.
Set `LC_ALL` inside the command if it needs another locale.

Other resources can trigger the command with
`notifies: [:run, "exec[NAME]"]`. Combined with `action: :nothing`, that
gives a command that runs only when something else changed, such as
`systemctl daemon-reload` after a unit file changed; see
[Notifications](../recipes/notifications.md).

## Scenarios

```ruby title="examples/resources/exec/recipe.rb"
--8<-- "examples/resources/exec/recipe.rb"
```

### Plan explains why each command will run

```text
--8<-- "docs/transcripts/exec-plan.txt"
```

The `git config` command is not listed: this machine has no `git`, so its
`only_if` guard skips it.

### After apply, the guards hold

```text
--8<-- "docs/transcripts/exec-apply.txt"
```

## Common mistakes

- **No guard.** An `exec` without `creates`, `not_if` or `only_if` runs on
  every apply, plan always lists it with "(no guard, runs on every
  apply)", and `drift` always reports it. Add a guard, or use
  `action: :nothing` if it should only run when notified.
- **Guards with side effects.** Guards run during `plan`. A guard such as
  `not_if: "mkdir /x"` changes the machine when you only asked to look.
- **Interactive commands.** Standard input is closed, so a command that
  prompts reads end-of-file and usually fails. Pass the tool's
  non-interactive flag (`-y`, `--noconfirm`).
- **A guard that never becomes true.** If the command does not create what
  the guard checks for, it runs every time. Check the exact path or setting
  the command produces.

## See also

- [package](package.md#aur-packages) for installing AUR packages with
  `exec`.
- [Recipe basics](../recipes/basics.md) for using `vars` in commands.
