# package

`package` makes sure a system package is installed, or not installed. Sadame
reads `/etc/os-release` to pick the package manager, so the same recipe works
on Debian and Ubuntu (apt), Rocky, AlmaLinux and Fedora (dnf), Alpine (apk),
and Arch and Arch-based systems such as Omarchy (pacman). Before acting it
asks the package manager whether the package is installed, and only installs
or removes when the answer differs from the recipe.

## Minimal example

```ruby title="examples/resources/package/minimal.rb"
--8<-- "examples/resources/package/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `state` | `:installed` or `:absent` | `:installed` | Whether the package must be installed. |
| `options` | String or Array of Strings | none | Extra flags for the install or remove command, placed before the package name. A String is used as is; Array elements are each shell-quoted. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |

## Commands per package manager

`NAME` is the package name, `OPTIONS` the `options:` value.

| Manager | Detected on | Installed when | Install | Remove |
|---|---|---|---|---|
| apt | `ID` or `ID_LIKE` is debian, ubuntu | `dpkg-query -W -f='${Status}' NAME` ends in `installed` | `DEBIAN_FRONTEND=noninteractive apt-get install -y OPTIONS NAME` | `DEBIAN_FRONTEND=noninteractive apt-get remove -y OPTIONS NAME` |
| dnf | rhel, centos, fedora, rocky, almalinux, ol | `rpm -q NAME` exits 0 | `dnf install -y OPTIONS NAME` | `dnf remove -y OPTIONS NAME` |
| apk | alpine | `apk info -e NAME` exits 0 | `apk add OPTIONS NAME` | `apk del OPTIONS NAME` |
| pacman | arch, archarm, manjaro, endeavouros | `pacman -Q NAME` exits 0 | `pacman -S --needed --noconfirm OPTIONS NAME` | `pacman -Rns --noconfirm OPTIONS NAME` |

Index refreshes:

- **apt**: `DEBIAN_FRONTEND=noninteractive apt-get update` runs once per
  `apply`, right before the first install. Runs that install nothing never
  touch the network.
- **dnf** and **apk** refresh their metadata themselves.
- **pacman**: sadame never runs `pacman -Sy`. Refreshing the sync database
  without upgrading (`-Sy` without `-u`) is a partial upgrade, which Arch
  does not support. Keep the system upgraded with `pacman -Syu` as usual.

## Scenarios

The recipe used below:

```ruby title="examples/resources/package/recipe.rb"
--8<-- "examples/resources/package/recipe.rb"
```

### Debian 12

```text
--8<-- "docs/transcripts/package-debian.txt"
```

### Arch Linux

The same recipe, unchanged, on Arch:

```text
--8<-- "docs/transcripts/package-arch.txt"
```

### Different names on different distributions

Package names are the distribution's own. Choose with plain Ruby:

```ruby title="examples/resources/package/by_family.rb"
--8<-- "examples/resources/package/by_family.rb"
```

```text
--8<-- "docs/transcripts/package-by-family.txt"
```

### AUR packages

The `package` resource does not install from the AUR in this release. Until
it does, use an AUR helper such as `yay` or `paru` through
[`exec`](exec.md), guarded so it only runs when the package is missing:

```ruby title="examples/resources/package/aur.rb"
--8<-- "examples/resources/package/aur.rb"
```

```ruby title="examples/resources/package/vars.rb"
--8<-- "examples/resources/package/vars.rb"
```

AUR helpers refuse to run as root, which is why the command goes through
`runuser`. The helper then calls `sudo pacman` itself, so that user needs to
be able to run `pacman` with sudo without a password prompt: sadame runs
commands with standard input closed and cannot answer one. Without `yay`
installed, `only_if` skips the resource:

```text
--8<-- "docs/transcripts/package-aur.txt"
```

## Common mistakes

- **Fresh Arch containers have no sync database.** In the `archlinux`
  Docker image, `pacman -S` warns "database file for 'core' does not exist"
  and fails with "target not found" until `pacman -Syu` has run once.
  Installed systems do not have this problem.
- **Package groups and virtual packages.** The installed check asks for the
  exact name. A group such as `base-devel` on Arch, or a name that is only
  provided by another package, never reports as installed, so it shows up in
  every plan. Declare the member packages instead.
- **Expecting upgrades.** `state: :installed` means "some version is
  installed". Sadame does not upgrade packages in this release.
- **Mixing families without a condition.** `package "apache2"` on Rocky
  fails at apply time with the package manager's own error.

## See also

- [exec](exec.md) for guarded commands, including the AUR workaround.
- [service](service.md) to enable and start what a package installs.
- [Recipe basics](../recipes/basics.md) for `platform` and `vars`.
