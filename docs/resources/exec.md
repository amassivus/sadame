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
| `notifies` | `[:action, "type[name]"]` or a list of them | none | Actions to run at the end of `apply` if the command ran. |

The command runs when every guard you gave agrees: the `creates` path is
missing, `not_if` exits non-zero, and `only_if` exits 0. Guards are checked
in that order and checking stops at the first one that says skip. Without
any guard, the command runs on every `apply`.

Commands and guards run with `/bin/sh` and standard input closed. A command
that exits non-zero fails the resource: `apply` prints the exit status and
the command's error output, marks the resource `failed`, and skips the
resources after it.

Other resources can trigger the command with
`notifies: [:run, "exec[NAME]"]`.

## Scenarios

```ruby title="examples/resources/exec/recipe.rb"
--8<-- "examples/resources/exec/recipe.rb"
```

### Plan explains why each command will run

```text
$ sudo sadame plan examples/resources/exec
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

+ directory[/opt/demo]
    state: absent -> present

! exec[tar -czf /opt/demo/etc-backup.tar.gz -C /etc hostname hosts]
    command: tar -czf /opt/demo/etc-backup.tar.gz -C /etc hostname hosts
    (/opt/demo/etc-backup.tar.gz does not exist)

! exec[echo 'EDITOR=vim' >> /etc/environment]
    command: echo 'EDITOR=vim' >> /etc/environment
    (not_if exited non-zero)

! exec[echo "built by $BUILDER" > build-info.txt]
    command: echo "built by $BUILDER" > build-info.txt
    (/opt/demo/build-info.txt does not exist)

Plan: 1 to create, 0 to update, 0 to remove, 3 to run, 1 unchanged.
```

The `git config` command is not listed: this machine has no `git`, so its
`only_if` guard skips it.

### After apply, the guards hold

```text
$ sudo sadame apply examples/resources/exec
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

changed    directory[/opt/demo]
           state: absent -> present
changed    exec[tar -czf /opt/demo/etc-backup.tar.gz -C /etc hostname hosts]
           command: tar -czf /opt/demo/etc-backup.tar.gz -C /etc hostname hosts
           (/opt/demo/etc-backup.tar.gz does not exist)
changed    exec[echo 'EDITOR=vim' >> /etc/environment]
           command: echo 'EDITOR=vim' >> /etc/environment
           (not_if exited non-zero)
unchanged  exec[git config --system init.defaultBranch main]
changed    exec[echo "built by $BUILDER" > build-info.txt]
           command: echo "built by $BUILDER" > build-info.txt
           (/opt/demo/build-info.txt does not exist)

Apply: 4 changed, 1 unchanged, 0 failed.

$ sudo sadame plan examples/resources/exec
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

Plan: 0 to create, 0 to update, 0 to remove, 0 to run, 5 unchanged.

$ cat /opt/demo/build-info.txt
built by sadame
```

## Common mistakes

- **No guard.** An `exec` without `creates`, `not_if` or `only_if` runs on
  every apply, and plan always lists it with "(no guard, runs on every
  apply)". That is rarely what you want.
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
