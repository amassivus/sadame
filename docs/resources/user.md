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
| `notifies` | `[:action, "type[name]"]` or a list of them | none | Actions to run at the end of `apply` if this resource changed. |

New users that are not system users get a home directory (`useradd -m`).
Changing `home` on an existing user updates the account but does not move
files.

## Scenarios

```ruby title="examples/resources/user/recipe.rb"
--8<-- "examples/resources/user/recipe.rb"
```

### A deploy user and a service account

```text
$ sudo sadame plan examples/resources/user
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

+ user[deploy]
    state: absent -> present
    shell: /bin/bash
    groups: adm

+ user[svc-backup]
    state: absent -> present
    home: /var/lib/svc-backup
    shell: /usr/sbin/nologin

Plan: 2 to create, 0 to update, 0 to remove, 0 to run, 0 unchanged.

$ sudo sadame apply examples/resources/user
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

changed    user[deploy]
           state: absent -> present
           shell: /bin/bash
           groups: adm
changed    user[svc-backup]
           state: absent -> present
           home: /var/lib/svc-backup
           shell: /usr/sbin/nologin

Apply: 2 changed, 0 unchanged, 0 failed.

$ id deploy
uid=1000(deploy) gid=1000(deploy) groups=1000(deploy),4(adm)
```

### Adding a user to the docker group

`groups:` only adds. A user already in `wheel` stays there:

```ruby title="examples/resources/user/docker_group.rb"
--8<-- "examples/resources/user/docker_group.rb"
```

```text
$ sudo sadame plan examples/resources/user/docker_group.rb
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

+ package[docker.io]
    state: absent -> installed

+ user[deploy]
    state: absent -> present
    groups: docker

Plan: 2 to create, 0 to update, 0 to remove, 0 to run, 0 unchanged.
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
