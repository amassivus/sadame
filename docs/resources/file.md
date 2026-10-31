# file

`file` manages a regular file: its content, permission bits and owner. The
content comes from a string, an ERB template, or a file shipped next to the
recipe. When the content differs, `plan` shows a unified diff of the file on
disk against the desired content. On `apply`, new content is written to a
temporary file in the same directory, given its final mode and owner, and
renamed over the target, so programs reading the file never see it half
written.

## Minimal example

```ruby title="examples/resources/file/minimal.rb"
--8<-- "examples/resources/file/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `content` | String | none | The exact file content. |
| `template` | String | none | ERB template, rendered with `vars` and `locals`. Looked up next to the recipe, then in its `templates/` directory. Absolute paths are used as is. |
| `source` | String | none | File copied as is. Looked up next to the recipe, then in its `files/` directory. |
| `locals` | Hash | `{}` | Values for the template, available as `locals[:name]`. Only with `template:`. |
| `mode` | String of 3 or 4 octal digits | unmanaged | Permission bits, such as `"0644"` or `"0755"`. |
| `owner` | String | unmanaged | User name that owns the file. |
| `group` | String | unmanaged | Group name of the file. |
| `state` | `:present` or `:absent` | `:present` | `:absent` deletes the file. |
| `sensitive` | `true` or `false` | `false` | Hide content diffs in output and JSON, for files holding secrets. |
| `notifies` | `[:action, "type[name]"]` or a list of them | none | Actions to run at the end of `apply` if this resource changed. |

Use at most one of `content`, `template` and `source`. With none of them,
sadame manages only the attributes you give and creates an empty file if it
is missing. Attributes you do not give are left alone; when the content is
replaced, the file keeps its current mode, owner and group.

## Scenarios

The recipe used below:

```ruby title="examples/resources/file/recipe.rb"
--8<-- "examples/resources/file/recipe.rb"
```

```erb title="examples/resources/file/templates/hello.conf.erb"
--8<-- "examples/resources/file/templates/hello.conf.erb"
```

```ruby title="examples/resources/file/vars.rb"
--8<-- "examples/resources/file/vars.rb"
```

### First apply

```text
$ sudo sadame apply examples/resources/file
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

changed    file[/etc/issue.net]
           --- /etc/issue.net
           +++ /etc/issue.net (desired)
           @@ -1 +1 @@
           -Debian GNU/Linux 12
           +Authorized access only.
changed    directory[/etc/hello]
           state: absent -> present
changed    file[/etc/hello/hello.conf]
           state: absent -> present
           mode: 0640
           owner: root
           group: root
           --- /dev/null
           +++ /etc/hello/hello.conf (desired)
           @@ -0,0 +1,5 @@
           +# Managed by sadame. Local changes will be overwritten.
           +listen = 8080
           +environment = staging
           +upstream = 10.0.0.11:9000
           +upstream = 10.0.0.12:9000
changed    file[/usr/local/bin/hello]
           state: absent -> present
           mode: 0755
           --- /dev/null
           +++ /usr/local/bin/hello (desired)
           @@ -0,0 +1,2 @@
           +#!/bin/sh
           +echo "hello from $(hostname)"
unchanged  file[/etc/hello/old.conf]

Apply: 4 changed, 1 unchanged, 0 failed.
```

### Changing a template variable

Rendering with a different var shows exactly which lines change:

```text
$ sudo sadame plan examples/resources/file --var environment=production
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

~ file[/etc/hello/hello.conf]
    --- /etc/hello/hello.conf
    +++ /etc/hello/hello.conf (desired)
    @@ -1,5 +1,5 @@
     # Managed by sadame. Local changes will be overwritten.
     listen = 8080
    -environment = staging
    +environment = production
     upstream = 10.0.0.11:9000
     upstream = 10.0.0.12:9000

Plan: 0 to create, 1 to update, 0 to remove, 0 to run, 4 unchanged.
```

In a terminal the diff is colored:

```diff
--- /etc/hello/hello.conf
+++ /etc/hello/hello.conf (desired)
@@ -1,5 +1,5 @@
 # Managed by sadame. Local changes will be overwritten.
 listen = 8080
-environment = staging
+environment = production
 upstream = 10.0.0.11:9000
 upstream = 10.0.0.12:9000
```

### Someone changed the permissions

Only the attribute that differs is reported, and `apply` only runs `chmod`:

```text
$ sudo chmod 0644 /etc/hello/hello.conf
$ sudo sadame plan examples/resources/file
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

~ file[/etc/hello/hello.conf]
    mode: 0644 -> 0640

Plan: 0 to create, 1 to update, 0 to remove, 0 to run, 4 unchanged.
```

## Common mistakes

- **Numeric modes.** `mode: 644` is rejected. Ruby reads `644` as decimal,
  which is not the mode you mean; write `mode: "0644"`.
- **Symlinks.** If the path is a symbolic link, the resource fails with
  "is a symbolic link, not a regular file" instead of replacing the link.
  Manage the link's target path instead.
- **Missing parent directory.** `file` does not create parent directories.
  Declare a `directory` resource before it.
- **Secrets in plan output.** Without `sensitive: true`, the diff of a file
  holding credentials is printed and included in `--json` output.
- **Template next to the wrong recipe.** Templates are found relative to the
  recipe file that declares the resource; see
  [Recipe basics](../recipes/basics.md#templates).

## See also

- [Recipe basics: templates](../recipes/basics.md#templates) for the
  template syntax.
- [directory](directory.md) for the parent directories.
- [service](service.md) to reload a service when its configuration changes.
