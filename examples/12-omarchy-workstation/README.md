# 12-omarchy-workstation

A personal workstation on [Omarchy](https://omarchy.org) or plain Arch
Linux, applied locally with no inventory: packages from the official
repositories, dotfiles from `files/` into your home directory, a systemd
user timer that cleans `~/Downloads`, and an AUR package through `yay`.
`drift` then tells you whether the laptop still matches the recipe.

**Who is this for:** Omarchy and Arch users who want to rebuild their
machine the same way every time.

| File | Purpose |
|---|---|
| `recipe.rb` | packages, dotfiles, the user timer, the AUR package |
| `vars.rb` | your user (from `sudo`), git identity, package lists |
| `templates/gitconfig.erb` | `~/.gitconfig` |
| `files/starship.toml` | `~/.config/starship.toml` |
| `files/update-system` | `~/.local/bin/update-system` |
| `files/clean-downloads.service`, `.timer` | the user timer, in `~/.config/systemd/user/` |

```sh
sudo sadame plan examples/12-omarchy-workstation
sudo sadame apply examples/12-omarchy-workstation
sudo sadame drift examples/12-omarchy-workstation; echo $?   # 0: nothing has wandered
```

Run it with `sudo`: packages need root, and `SUDO_USER` says whose home
directory to manage. The AUR step needs `yay` (Omarchy ships it) and
passwordless sudo for `pacman`, because sadame cannot answer a password
prompt.

**Testing.** In the Docker matrix this runs on `archlinux:latest`, where
`yay` is missing and the AUR step is skipped by its `only_if` guard. It
runs fully only on an Omarchy VM, and needs a real boot (user sessions,
lingering), so it only counts as passing after the VM layer (see
[Testing](../../docs/contributing/testing.md)).
