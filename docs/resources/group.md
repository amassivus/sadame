# group

`group` makes sure a local group exists, with the gid you give, or that it
does not exist. It reads the group with `getent group` and changes it with
`groupadd`, `groupmod` and `groupdel` only when something differs. Members
are set on the user side, with the [user](user.md) resource's `groups:`.

!!! note "New in 0.2.0"

## Minimal example

```ruby title="examples/resources/group/minimal.rb"
--8<-- "examples/resources/group/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `gid` | Integer | unmanaged | Numeric group ID. Changing it on an existing group runs `groupmod -g`; files keep their old gid. |
| `system` | `true` or `false` | `false` | Create a system group (`groupadd -r`), with a gid from the system range. Only used when the group is created. |
| `state` | `:present` or `:absent` | `:present` | `:absent` deletes the group with `groupdel`. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

On Alpine without the `shadow` package, sadame uses BusyBox's `addgroup`
and `delgroup` instead. BusyBox cannot change a gid; declare
`package "shadow"` first if you need to.

## Scenarios

```ruby title="examples/resources/group/recipe.rb"
--8<-- "examples/resources/group/recipe.rb"
```

### Groups on a new server

```text
--8<-- "docs/transcripts/group.txt"
```

`group[oldteam]` is unchanged because it does not exist, which is what
`state: :absent` asks for.

### A group and its members

Declare the group before the users that join it; the user resource needs
its groups to exist:

```ruby
group "app", gid: 1500
user "deploy", groups: ["app"]
```

## Common mistakes

- **A group that a user is still in.** `groupdel` refuses to delete a group
  that is some user's primary group. Remove or change the user first.
- **A gid that is taken.** `groupadd -g` and `groupmod -g` fail when
  another group already has that gid; the error names it.
- **Expecting a gid change to fix file ownership.** Files store the
  number, so after a change they show the old gid. Fix them with `chown`
  or a [directory](directory.md) resource's `group:`.

## See also

- [user](user.md) to add users to the group.
- [directory](directory.md) and [file](file.md) for files owned by the group.
