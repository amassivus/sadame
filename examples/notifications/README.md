# notifications

A systemd service managed together with its unit file and settings, used on
the [Notifications](../../docs/recipes/notifications.md) page. It shows:

- `notifies:` with `:immediately` (reload systemd before anything else),
- `notifies:` with the default delayed timing (restart once, at the end),
- `subscribes:` (the service watches its settings file),
- `exec` with `action: :nothing` (a command that only runs when notified).

**Who is this for:** recipe authors managing services and their
configuration.

Needs root and systemd.

```sh
sudo sadame apply examples/notifications
sudo sadame plan examples/notifications --var interval=30
sudo sadame apply examples/notifications --var interval=30
```
