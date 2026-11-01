# Tags

Tags let you plan, apply or check part of a recipe: only nginx's
configuration, only the database role, everything but the slow package
installs. Give resources `tags:`, or tag everything an included file
declares, then run with `--tags` or `--skip-tags`.

!!! note "New in 0.4.0"

## Minimal example

```ruby
package "nginx", tags: [:nginx]
file "/etc/nginx/conf.d/app.conf", template: "app.conf.erb", tags: [:nginx, :config]
```

```sh
sudo sadame apply --tags config        # only the configuration file
```

## Tagging

| Where | Example | Tags |
|---|---|---|
| a resource | `package "nginx", tags: [:web]` | `web` |
| one tag | `user "deploy", tags: :users` | `users` |
| an included file | `include_recipe "roles/web", tags: [:web]` | `web` on every resource `roles/web.rb` declares, and on the files it includes |

Tags are Symbols or Strings without commas or spaces. A resource has its
own tags and those of every `include_recipe` it came through.

## Running part of a recipe

| Option | Runs |
|---|---|
| `--tags web,db` | only resources with at least one of these tags |
| `--skip-tags slow` | every resource except those with one of these tags |
| both | resources with one of the `--tags`, minus those with one of the `--skip-tags` |

Both work with `plan`, `apply` and `drift`, locally and on remote hosts.
The resources left out are not read or changed, and do not appear in the
report; the header says how many were selected, and JSON reports list the
tags under `tags` and `skip_tags`.

`examples/08-multi-role-inventory` tags each role:

```ruby title="examples/08-multi-role-inventory/site.rb"
--8<-- "examples/08-multi-role-inventory/site.rb"
```

so the web role can be planned on its own:

```text
--8<-- "docs/transcripts/remote-tags.txt"
```

## Notifications

A notification runs even when its target is not selected. With
`--tags config`, a configuration file that changes still reloads the
service it notifies, though the service itself is not checked: the reload
is part of changing the file.

## Common mistakes

- **Expecting untagged resources to run.** With `--tags`, a resource
  without tags is never selected; that includes base resources such as
  the login banner above. Tag what belongs to a role, and use
  `--skip-tags` when you want everything but something.
- **Drift with tags.** `drift --tags web` checks only the web resources.
  Keep the scheduled drift check without tags, so it covers everything.
- **A tag that matches nothing.** sadame does not treat that as an error,
  because a tag can exist on some hosts and not on others. The header shows
  "0 of N"; check the spelling when you see it.
- **Including a file twice with different tags.** A file is evaluated once,
  the first time it is included; later `include_recipe` calls and their
  tags are ignored.

## See also

- [Recipe basics](basics.md) for `include_recipe`.
- [Notifications](notifications.md) for what runs when a resource changes.
- [Command line](../reference/cli.md) for every option.
