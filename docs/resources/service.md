# service

`service` manages a service: whether it starts at boot (`enable`) and
whether it is running now (`state`). It works with systemd, and with OpenRC
on Alpine. It reads the current state with `systemctl is-enabled` and
`systemctl is-active` (or `rc-update show` and `rc-service NAME status`)
and only changes what differs. Other resources can ask a service to reload
or restart when they change, through `notifies:`.

## Minimal example

```ruby title="examples/resources/service/recipe.rb"
--8<-- "examples/resources/service/recipe.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | `true` or `false` | unmanaged | Start at boot (`systemctl enable`) or not (`systemctl disable`). Enabled means `systemctl is-enabled` prints `enabled`. |
| `state` | `:running` or `:stopped` | unmanaged | Running now (`systemctl start`) or not (`systemctl stop`). Running means `systemctl is-active` prints `active`. |
| `user` | String | none | Manage the unit in this user's systemd instance (`systemctl --user -M USER@`), such as a unit in `~/.config/systemd/user/`. The user must be logged in or have lingering enabled (`loginctl enable-linger USER`). systemd only. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

A service with neither option manages nothing by itself; it is still a valid
target for notifications.

## OpenRC

On a host that runs OpenRC instead of systemd, as Alpine does, the same
recipe works with OpenRC's commands. sadame checks for
`/run/systemd/system` first, then for `/run/openrc/softlevel`.

| | systemd | OpenRC |
|---|---|---|
| Enabled means | `systemctl is-enabled` prints `enabled` | the service is in a runlevel (`rc-update show`) |
| `enable: true` | `systemctl enable NAME` | `rc-update add NAME default` |
| `enable: false` | `systemctl disable NAME` | `rc-update del NAME RUNLEVEL` for each runlevel it is in |
| Running means | `systemctl is-active` prints `active` | `rc-service NAME status` exits 0 |
| `state: :running` | `systemctl start NAME` | `rc-service NAME start` |

!!! note "New in 0.2.0"

    sadame 0.1.0 supports systemd only.

```text
--8<-- "docs/transcripts/service-openrc.txt"
```

## Actions for notifications

Other resources can trigger these with `notifies: [:action, "service[name]"]`:

| Action | Runs with systemd | Runs with OpenRC |
|---|---|---|
| `:start` | `systemctl start NAME` | `rc-service NAME start` |
| `:stop` | `systemctl stop NAME` | `rc-service NAME stop` |
| `:restart` | `systemctl restart NAME` | `rc-service NAME restart` |
| `:reload` | `systemctl reload NAME` | `rc-service NAME reload` |
| `:enable` | `systemctl enable NAME` | `rc-update add NAME default` |
| `:disable` | `systemctl disable NAME` | `rc-update del NAME RUNLEVEL` |

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

- **No service manager.** The resource needs systemd or OpenRC running.
  In most containers neither runs, and it fails with "no service manager
  is running on this host".
- **Declaring the service before its package.** On a fresh machine the unit
  does not exist yet, so plan shows it as disabled and stopped, and `apply`
  fails if the package comes later in the recipe. Put `package` first.
- **Units that cannot be enabled.** `systemctl is-enabled` prints `static`
  for units without an `[Install]` section. Those never count as enabled, so
  `enable: true` on them shows a change on every plan. Leave `enable` out.
- **Expecting a reload when only the service changed.** `reload` and
  `restart` happen only through notifications from other resources.
- **Reloading a service that cannot reload.** `systemctl reload` fails for
  units without `ExecReload=`, and `rc-service NAME reload` for init
  scripts without a reload command. Notify `:restart` for those.
- **Different names on different systems.** The SSH server is `ssh` on
  Debian and Ubuntu and `sshd` elsewhere; cron is `cron`, `crond` or
  `cronie`. Pick the name from `platform.family`.

## See also

- [package](package.md) to install the software first.
- [file](file.md) for configuration files that notify the service.
