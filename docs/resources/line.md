# line

`line` manages one line in a file that something else owns, such as a
setting in the configuration file a package installs, and leaves the rest
of the file alone. When the file would change, plan shows the change as a
diff of the file, and apply writes it in one rename, keeping the file's
mode and owner.

Use [file](file.md) when sadame should own the whole file; use `line` when
the package should keep owning it and you only need one setting.

!!! note "New in 0.2.0"

## Minimal example

```ruby title="examples/resources/line/minimal.rb"
--8<-- "examples/resources/line/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `path` | String | required | Absolute path of the file to edit. |
| `line` | String | the name | The line, without a newline. Give it when the name is a description, or when the same line goes into two files. |
| `match` | Regexp, or a String with one | none | Lines to replace. Every line that matches is replaced by the line; when none matches and the line is not in the file, it is appended. |
| `state` | `:present` or `:absent` | `:present` | `:absent` removes the line, and every line that matches `match`. |
| `verify` | String containing `%{path}` | none | A command that checks the new content before it replaces the file, such as `"sshd -t -f %{path}"`. If it fails, the file is not changed. |
| `sensitive` | `true` or `false` | `false` | Hide the diff in output and JSON, for lines with secrets. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

Without `match`, the line is appended when no line in the file is exactly
the same. Lines are compared without their newline; spaces count.

The file must exist when the change is applied: `line` edits files, it
does not create them. On a machine where the file comes from a package that
the same recipe installs, plan shows the line being added to a file that
"does not exist yet", and apply edits the file the package created.

## Scenarios

```ruby title="examples/resources/line/recipe.rb"
--8<-- "examples/resources/line/recipe.rb"
```

### Hardening the SSH server's configuration

The plan shows each edit as a diff of `sshd_config`. With `match`, the
commented-out default line becomes the setting, so the file still reads in
the order the package wrote it:

```text
--8<-- "docs/transcripts/line-plan.txt"
```

```text
--8<-- "docs/transcripts/line-apply.txt"
```

The edits do not restart the SSH server. Add
`notifies: [:restart, "service[ssh]"]` (`sshd` on Rocky Linux and Arch)
when they should take effect right away.

## Writing match

`match` is a regular expression for one line, without its newline. Make it
match every form the setting can take in the file, commented out or not,
with or without spaces, so that the line replaces the setting instead of
being appended after it:

| You want | match |
|---|---|
| `Port 2222` where the file has `#Port 22` | `/^#?\s*Port\s/` |
| `vm.swappiness = 10` where the file may have `vm.swappiness=60` | `/^#?\s*vm\.swappiness\s*=/` |
| `include_dir = 'conf.d'` in `postgresql.conf` | `/^#?\s*include_dir\s*=/` |

When more than one line matches, every one of them is replaced, so the file
ends up with the same line twice rather than two different values.

## Common mistakes

- **Managing the same file with `file` and `line`.** The `file` resource
  writes the whole content on every run and `line` changes it again, so
  neither ever reports "unchanged". Use one or the other.
- **A `match` that misses the active setting.** If the file has
  `PermitRootLogin yes` and `match` is `/^#PermitRootLogin/`, nothing
  matches, so `PermitRootLogin no` is appended at the end, and sshd keeps
  the first value it reads: `yes`. Cover both forms:
  `/^#?\s*PermitRootLogin\s/`.
- **Expecting `line` to create the file.** It fails with "does not exist".
  Create the file with [file](file.md), or install the package that ships
  it, earlier in the recipe.

## See also

- [file](file.md) to own a whole file.
- [exec](exec.md) for edits that are not one line.
