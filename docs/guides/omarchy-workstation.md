# Keep an Omarchy workstation reproducible

[Omarchy](https://omarchy.org) sets up Arch Linux as a complete desktop.
What you add on top (packages, dotfiles, a timer or two, something from the
AUR) is usually done by hand and remembered by nobody. This guide keeps
that layer in a recipe: a fresh Omarchy install plus `sadame apply` gives
the same machine, and `sadame drift` answers "did I break my laptop?" in
one command. It uses `examples/12-omarchy-workstation`.

## The recipe

```ruby title="examples/12-omarchy-workstation/recipe.rb"
--8<-- "examples/12-omarchy-workstation/recipe.rb"
```

```ruby title="examples/12-omarchy-workstation/vars.rb"
--8<-- "examples/12-omarchy-workstation/vars.rb"
```

Copy the directory somewhere you keep under version control, edit
`vars.rb` and the files in `files/` and `templates/`, and add your own.

## What belongs in the recipe, and what does not

| In the recipe | Left to Omarchy |
|---|---|
| packages you install on top of Omarchy | the packages Omarchy installs |
| your dotfiles: git identity, shell prompt, editor settings | Omarchy's own configuration (Hyprland, Waybar, its themes) |
| your scripts in `~/.local/bin` | Omarchy's scripts and its update mechanism |
| your systemd user units and timers | Omarchy's services |
| AUR packages you rely on | `yay` itself, which Omarchy ships |

The rule of thumb: manage what you would have to redo by hand after a
reinstall, and leave the files Omarchy installs and updates alone. If the
recipe managed them too, every Omarchy update would show up as drift, and
every apply would undo the update. When you do change one of Omarchy's
settings, make the change the way Omarchy's documentation describes for
local changes, so its updates and your recipe do not overwrite each other,
and manage only your part.

## Running it

On a fresh install, the plan shows everything the recipe will add. Run it
with `sudo`: packages need root, and `SUDO_USER` tells the recipe whose
home directory to manage. The output below comes from an Arch Linux ARM
container on an ARM64 machine, where `yay` is missing, so the AUR step is
skipped; on Omarchy it runs.

```text
--8<-- "docs/transcripts/omarchy-plan.txt"
```

```text
--8<-- "docs/transcripts/omarchy-apply.txt"
```

The two `notified` lines are `systemctl --user daemon-reload` running
right after each unit file was written (`:immediately`), before the timer
is enabled.

## Did I break my laptop?

```text
--8<-- "docs/transcripts/omarchy-drift-clean.txt"
```

Now edit `~/.gitconfig` by hand and delete a script, as one does:

```text
--8<-- "docs/transcripts/omarchy-drift-broken.txt"
```

`apply` puts both back:

```text
--8<-- "docs/transcripts/omarchy-repair.txt"
```

Running `sudo sadame drift ...` from time to time, or from a systemd user
timer, tells you when the machine has wandered from what you wrote down.

## From a fresh install to the same machine

1. Install Omarchy.
2. Clone the repository with your recipe.
3. Install sadame (see [Install](../install.md)).
4. `sudo sadame apply path/to/your-recipe`
5. `sudo sadame drift path/to/your-recipe`; exit status `0` means done.

## Common mistakes

- **Running without sudo, or as root directly.** Without `sudo`,
  installing packages fails; as root without `sudo`, `SUDO_USER` is empty
  and the recipe stops. Pass `--var user=NAME` if you must.
- **The AUR step asking for a password.** `yay` runs `sudo pacman`, and
  sadame cannot answer a prompt. Run `sudo -v` just before, or allow
  `pacman` without a password.
- **Managing Omarchy's own files.** See the table above.
- **Upgrading packages with the recipe.** `package` means "installed", not
  "latest"; keep updating with `pacman -Syu` (or `update-system` from the
  example).

## See also

- [`12-omarchy-workstation`](../examples/index.md)
- [service](../resources/service.md) for `user:` units.
- [package](../resources/package.md#aur-packages) for AUR packages.
