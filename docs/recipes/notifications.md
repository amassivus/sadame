# Notifications

A notification runs an action on one resource because another resource
changed: reload nginx after its configuration file changed, run
`systemctl daemon-reload` after a unit file changed, restart a service when
its settings changed. Nothing is triggered when the watched resource was
already as the recipe wants it, so a service is only restarted when there is
a reason to. By default a notified action runs once, at the end of `apply`,
however many resources asked for it; marked `:immediately`, it runs right
after the change that triggered it.

## Minimal example

```ruby title="examples/resources/service/reload_on_change.rb"
--8<-- "examples/resources/service/reload_on_change.rb"
```

## Options

Both options are available on every resource.

| Option | Form | Meaning |
|---|---|---|
| `notifies` | `[:action, "type[name]"]` | When this resource changes, run `action` on the named resource. |
| `subscribes` | `[:action, "type[name]"]` | When the named resource changes, run `action` on this resource. |
| either | `[:action, "type[name]", :immediately]` | Run the action right after the change instead of at the end. |
| either | `[:action, "type[name]", :delayed]` | The default, written out. |
| either | `[[...], [...]]` | Several notifications from one resource. |

`subscribes` is `notifies` declared from the other side; use whichever
reads better. Actions each resource type accepts:

| Resource | Actions |
|---|---|
| `service` | `:start`, `:stop`, `:restart`, `:reload`, `:enable`, `:disable` |
| `exec` | `:run` |
| `package`, `file`, `directory`, `user` | none |

`exec` also takes `action: :nothing`: the command then never runs on its
own, only when notified. That is the usual way to write "run this after
that changed".

## How notifications run

- Only a resource that **changed** during `apply` triggers its
  notifications. Unchanged, failed and skipped resources trigger nothing.
- **Delayed** notifications (the default) run after the last resource, in
  the order they were first triggered. Each action on each resource runs
  once: if three configuration files ask to restart nginx, it restarts once.
- **Immediate** notifications run right after the resource that triggered
  them, every time they are triggered, before the next resource is looked
  at.
- If a resource fails, the run stops: later resources are skipped and
  delayed notifications do not run. A failed immediate notification stops
  the run in the same way.
- `plan` and `drift` never run notifications. They list, under each
  resource that would change, what it would trigger.
- Every notification must name a declared resource and an action it
  supports. Mistakes are reported when the recipe loads, before anything
  runs.

## Scenarios

The example below manages a small systemd service together with its unit
file and settings:

```ruby title="examples/notifications/recipe.rb"
--8<-- "examples/notifications/recipe.rb"
```

```erb title="examples/notifications/templates/ticker.service.erb"
--8<-- "examples/notifications/templates/ticker.service.erb"
```

```ruby title="examples/notifications/vars.rb"
--8<-- "examples/notifications/vars.rb"
```

### First apply

The unit file is new, so `systemctl daemon-reload` runs immediately after
it, before the service is enabled and started. At the end, the delayed
restart runs once, although both files asked for it:

```text
--8<-- "docs/transcripts/notifications-first-apply.txt"
```

### Changing a setting

`plan` shows which notifications a change would trigger:

```text
--8<-- "docs/transcripts/notifications-plan-interval.txt"
```

`apply` restarts the service once the settings file is written:

```text
--8<-- "docs/transcripts/notifications-apply-interval.txt"
```

### Changing the unit file

A changed unit file triggers both: `daemon-reload` right away, the restart
at the end.

```text
--8<-- "docs/transcripts/notifications-unit-change.txt"
```

## Common mistakes

- **Delayed daemon-reload.** `systemctl daemon-reload` after a unit file
  change must happen before the service is started or restarted. Mark it
  `:immediately`; a delayed reload runs after the restart it was meant to
  prepare.
- **An `exec` without `action: :nothing`.** A notified `exec` that also
  has no guard runs on every apply anyway, and `drift` always reports it.
- **Reloading a unit that cannot reload.** `systemctl reload` fails for
  units without `ExecReload=`; notify `:restart` instead.
- **Expecting a notification after a failed run.** Delayed notifications
  are skipped when a resource fails. Fix the failure and apply again; the
  resource that changed earlier is now unchanged and will not notify again,
  so restart by hand if needed.
- **Typos in the target.** `"service[ngnix]"` is reported when the recipe
  loads: `file[/etc/nginx/nginx.conf] notifies service[ngnix], which is not
  declared`.

## See also

- [service](../resources/service.md) for the service actions.
- [exec](../resources/exec.md) for `action: :nothing`.
- [Plan, apply, drift](../concepts/plan-apply-drift.md) for what each
  command does with notifications.
