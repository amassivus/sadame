# user

`user` manages a local Linux user account: whether it exists, its UID, home
directory, login shell, and the groups it must belong to. It reads the
account with `getent passwd` and `id -nG`, and changes it with `useradd`,
`usermod` and `userdel` only when something differs.

## Minimal example

```ruby title="examples/resources/user/minimal.rb"
--8<-- "examples/resources/user/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `uid` | Integer | unmanaged | Numeric user ID. |
| `home` | String | unmanaged | Home directory path. |
| `shell` | String | unmanaged | Login shell, such as `"/bin/bash"` or `"/usr/sbin/nologin"`. |
| `groups` | Array of Strings | unmanaged | Groups the user must belong to. Other memberships are left alone. The groups must exist. |
| `system` | `true` or `false` | `false` | Create a system account (`useradd -r`), which gets no home directory. Only used when the user is created. |
| `state` | `:present` or `:absent` | `:present` | `:absent` deletes the account with `userdel`; the home directory is kept. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

New users that are not system users get a home directory (`useradd -m`).
Changing `home` on an existing user updates the account but does not move
files.

## Scenarios

```ruby title="examples/resources/user/recipe.rb"
--8<-- "examples/resources/user/recipe.rb"
```

### A deploy user and a service account

```text
--8<-- "docs/transcripts/user.txt"
```

### Adding a user to the docker group

`groups:` only adds. A user already in `wheel` stays there:

```ruby title="examples/resources/user/docker_group.rb"
--8<-- "examples/resources/user/docker_group.rb"
```

```text
--8<-- "docs/transcripts/user-docker-group.txt"
```

### Removing an account

```ruby title="examples/resources/user/remove.rb"
--8<-- "examples/resources/user/remove.rb"
```

## Common mistakes

- **Groups that do not exist yet.** `useradd -G docker` fails if the
  `docker` group has not been created. Declare the package that creates it
  first.
- **Alpine without shadow.** Alpine's BusyBox has no `useradd`. Declare
  `package "shadow"` before any `user` resource; without it the resource
  fails with a message saying so.
- **Expecting a group list to be exact.** Removing a group from `groups:`
  does not remove the user from that group.
- **Clashing with existing accounts.** Many distributions ship system users
  such as `backup` or `www-data`. Declaring one of those with a different
  `home` or `shell` changes the existing account.

## See also

- [directory](directory.md) and [file](file.md) for files the user owns.
- [package](package.md) for packages that create groups.
