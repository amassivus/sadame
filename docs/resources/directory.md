# directory

`directory` makes sure a directory exists, with the permission bits and
owner you give, or that it does not exist. Missing parent directories are
created along the way. Use it before `file` resources that write into a new
directory, and to keep application directories owned by the right user.

## Minimal example

```ruby title="examples/resources/directory/minimal.rb"
--8<-- "examples/resources/directory/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `mode` | String of 3 or 4 octal digits | unmanaged | Permission bits, such as `"0755"`. |
| `owner` | String | unmanaged | User name that owns the directory. |
| `group` | String | unmanaged | Group name of the directory. |
| `state` | `:present` or `:absent` | `:present` | `:absent` removes the directory. |
| `recursive` | `true` or `false` | `false` | With `state: :absent`, remove the directory and everything in it (`rm -rf`). Without it, only an empty directory can be removed (`rmdir`). |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |
| `tags` | Symbol, String, or an Array of them | none | Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](../recipes/tags.md). |

Creating runs `mkdir -p`, then `chmod` and `chown` for the attributes you
gave. Parents created by `mkdir -p` get default permissions; declare them as
their own resources if they matter.

## Scenarios

```ruby title="examples/resources/directory/recipe.rb"
--8<-- "examples/resources/directory/recipe.rb"
```

### Application directories on a new server

```text
--8<-- "docs/transcripts/directory.txt"
```

`directory[/srv/app/tmp]` is unchanged because it does not exist, which is
what `state: :absent` asks for.

### Removing a directory

The last resource in the recipe removes `/srv/app/tmp` and everything in it
whenever it shows up. Without `recursive: true`, removing a directory that
still has files in it fails with `rmdir`'s error, which protects you from
deleting more than you meant to.

## Common mistakes

- **Owner that does not exist yet.** `owner: "www-data"` fails if the user
  is created later in the recipe, or by a package declared after the
  directory. Order the `package` or `user` resource first.
- **A file in the way.** If the path exists as a regular file, the resource
  fails with "is a regular file, not a directory"; sadame does not delete it
  for you.
- **Expecting `mode` to apply to the contents.** Only the directory itself
  is changed, never the files inside.

## See also

- [file](file.md) for files inside the directory.
- [user](user.md) for the owner.
