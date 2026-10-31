# service

`service` manages a systemd unit: whether it starts at boot (`enable`) and
whether it is running now (`state`). It reads the current state with
`systemctl is-enabled` and `systemctl is-active` and only calls `systemctl`
to change what differs. Other resources can ask a service to reload or
restart when they change, through `notifies:`.

## Minimal example

```ruby title="examples/resources/service/minimal.rb"
--8<-- "examples/resources/service/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | `true` or `false` | unmanaged | Start at boot (`systemctl enable`) or not (`systemctl disable`). Enabled means `systemctl is-enabled` prints `enabled`. |
| `state` | `:running` or `:stopped` | unmanaged | Running now (`systemctl start`) or not (`systemctl stop`). Running means `systemctl is-active` prints `active`. |
| `user` | String | none | Manage the unit in this user's systemd instance (`systemctl --user -M USER@`), such as a unit in `~/.config/systemd/user/`. The user must be logged in or have lingering enabled (`loginctl enable-linger USER`). |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

A service with neither option manages nothing by itself; it is still a valid
target for notifications.

## Actions for notifications

Other resources can trigger these with `notifies: [:action, "service[name]"]`:

| Action | Runs |
|---|---|
| `:start` | `systemctl start NAME` |
| `:stop` | `systemctl stop NAME` |
| `:restart` | `systemctl restart NAME` |
| `:reload` | `systemctl reload NAME` |
| `:enable` | `systemctl enable NAME` |
| `:disable` | `systemctl disable NAME` |

Actions run only when the notifying resource changed. By default they run
once each, after all resources; add `:immediately` to run one right away.
See the scenario below and [Notifications](../recipes/notifications.md).

## Scenarios

```ruby title="examples/resources/service/recipe.rb"
--8<-- "examples/resources/service/recipe.rb"
```

### Installing and starting nginx

On this Debian 12 machine the nginx package was enabled on install but not
started. Each resource reads its current state right before it runs, so by
the time `service[nginx]` is applied, only the running state is left to
change:

```text
--8<-- "docs/transcripts/service-install.txt"
```

### Someone stopped and disabled it

```text
--8<-- "docs/transcripts/service-repair.txt"
```

### Reloading after a configuration change

```ruby title="examples/resources/service/reload_on_change.rb"
--8<-- "examples/resources/service/reload_on_change.rb"
```

```text
--8<-- "docs/transcripts/service-reload.txt"
```

On the next run nothing changes, so nothing is reloaded.

## Common mistakes

- **No systemd.** The resource needs a running systemd (it checks for
  `/run/systemd/system`). In containers without systemd, and on Alpine with
  OpenRC, it fails with "systemd is not running on this host".
- **Declaring the service before its package.** On a fresh machine the unit
  does not exist yet, so plan shows it as disabled and stopped, and `apply`
  fails if the package comes later in the recipe. Put `package` first.
- **Units that cannot be enabled.** `systemctl is-enabled` prints `static`
  for units without an `[Install]` section. Those never count as enabled, so
  `enable: true` on them shows a change on every plan. Leave `enable` out.
- **Expecting a reload when only the service changed.** `reload` and
  `restart` happen only through notifications from other resources.
- **Reloading a service that cannot reload.** `systemctl reload` fails for
  units without `ExecReload=`. Notify `:restart` for those.

## See also

- [package](package.md) to install the software first.
- [file](file.md) for configuration files that notify the service.
