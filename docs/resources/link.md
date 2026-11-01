# link

`link` makes sure a symbolic link exists and points where you say, or that
it does not exist. It reads the link with `readlink`, creates or repoints
it with `ln -sfn`, and removes it with `rm -f`. Use it for the classic
"enabled" links (`sites-enabled/app`), for a `current` link between
releases, and to put a program on the `PATH`.

!!! note "New in 0.2.0"

## Minimal example

```ruby
link "/etc/nginx/sites-enabled/app", to: "/etc/nginx/sites-available/app"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `to` | String | required | Where the link points. Stored as given: a relative target such as `"releases/2"` is relative to the link's directory. The target does not have to exist. |
| `state` | `:present` or `:absent` | `:present` | `:absent` removes the link. |
| `force` | `true` or `false` | `false` | Replace a regular file that is where the link should be. Without it, a file in the way is an error. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

The link's directory must exist; declare it with a
[directory](directory.md) resource first if it does not. A directory where
the link should be is always an error, even with `force: true`.

## Scenarios

```ruby title="examples/resources/link/recipe.rb"
--8<-- "examples/resources/link/recipe.rb"
```

### Releases and a current link

```text
--8<-- "docs/transcripts/link.txt"
```

### Someone pointed it at the old release

```text
--8<-- "docs/transcripts/link-repoint.txt"
```

### Reloading a service when a link changes

A link that enables a configuration can notify the service that reads it:

```ruby
link "/etc/nginx/sites-enabled/app",
     to: "/etc/nginx/sites-available/app",
     notifies: [:reload, "service[nginx]"]
```

## Common mistakes

- **A file in the way.** A path that exists as a regular file fails with
  "is a regular file, not a symbolic link". Add `force: true` when
  replacing it is what you want, as for `/etc/resolv.conf`.
- **Relative targets.** `to: "releases/2"` is relative to the link's
  directory, not to the directory you run sadame from. sadame compares the
  target as written: `to: "/srv/app/releases/2"` and `to: "releases/2"`
  are different links, even when they lead to the same place.
- **Expecting the link to create its directory.** `ln` fails when the
  directory does not exist.

## See also

- [file](file.md) and [directory](directory.md) for what the link points to.
- [service](service.md) for services that read linked configuration.
