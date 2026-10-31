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
| `notifies` | `[:action, "type[name]"]` or a list of them | none | Actions to run at the end of `apply` if this resource changed. |

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

Notified actions run once each, after all resources, and only when the
notifying resource changed. See the scenario below.

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
$ sudo sadame plan examples/resources/service
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

+ package[nginx]
    state: absent -> installed

~ service[nginx]
    enabled: false -> true
    state: stopped -> running

Plan: 1 to create, 1 to update, 0 to remove, 0 to run, 0 unchanged.

$ sudo sadame apply examples/resources/service
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

changed    package[nginx]
           state: absent -> installed
changed    service[nginx]
           state: stopped -> running

Apply: 2 changed, 0 unchanged, 0 failed.
```

### Someone stopped and disabled it

```text
$ sudo systemctl stop nginx && sudo systemctl disable nginx
$ sudo sadame plan examples/resources/service
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

~ service[nginx]
    enabled: false -> true
    state: stopped -> running

Plan: 0 to create, 1 to update, 0 to remove, 0 to run, 1 unchanged.

$ sudo sadame apply examples/resources/service
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

unchanged  package[nginx]
changed    service[nginx]
           enabled: false -> true
           state: stopped -> running

Apply: 1 changed, 1 unchanged, 0 failed.
```

### Reloading after a configuration change

```ruby title="examples/resources/service/reload_on_change.rb"
--8<-- "examples/resources/service/reload_on_change.rb"
```

```text
$ sudo sadame apply examples/resources/service/reload_on_change.rb
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

changed    package[nginx]
           state: absent -> installed
changed    file[/etc/nginx/conf.d/status.conf]
           state: absent -> present
           mode: 0644
           --- /dev/null
           +++ /etc/nginx/conf.d/status.conf (desired)
           @@ -0,0 +1,4 @@
           +server {
           +  listen 127.0.0.1:8080;
           +  location = /status { stub_status; }
           +}
changed    service[nginx]
           state: stopped -> running
notified   service[nginx]: reload (from file[/etc/nginx/conf.d/status.conf])

Apply: 3 changed, 0 unchanged, 0 failed.
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

## See also

- [package](package.md) to install the software first.
- [file](file.md) for configuration files that notify the service.
