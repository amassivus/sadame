# Config management in plain Ruby, in one binary

A 10-minute lightning talk with a live demo on an Omarchy laptop.

## Outline

| Time | Part | Points |
|---|---|---|
| 0:00 | The problem | Machines drift: someone edits a file by hand, a package is removed, a timer is disabled. Most tools find out only when they run again, and need Python, Ruby or an agent on every machine. |
| 1:00 | Recipes are Ruby | Show `examples/quickstart/recipe.rb`: three resources. Loops, conditions and methods are plain Ruby; no YAML templating on top. |
| 2:00 | One binary | mruby compiles sadame, its template engine and the recipes' runtime into one static binary of about 1 MB. For a remote host it copies itself over scp, keyed by checksum, and runs over ssh. Nothing stays running. |
| 3:00 | Live demo | plan, apply, break something, drift catches it (script below). |
| 7:00 | How it is tested | Every example applied and drift-checked on five distributions, two architectures, in containers booting systemd. A run on real VMs found what containers could not: a translated `stat` output and an `ssh.socket` that locked Ubuntu out. |
| 8:30 | Limits | 0.1.0: six resource types, Linux targets only, no secrets management, no central server. The comparison page says where Ansible, Chef or Puppet fit better. |
| 9:30 | Where to find it | Docs and repository links on the last slide; ask for the resource you need first. |

## Before the talk

On the laptop, an hour before:

1. Install sadame and get the examples:

    ```sh
    curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
    git clone https://github.com/enderkus/sadame.git && cd sadame
    ```

2. Apply example 12 once, so the slow parts (pacman downloads, the AUR
   build) are done before anyone watches:

    ```sh
    sudo sadame apply examples/12-omarchy-workstation
    sudo sadame drift examples/12-omarchy-workstation; echo $?   # must print 0
    ```

3. Undo one file, so the plan in the demo has something to show:

    ```sh
    rm ~/.config/starship.toml
    ```

4. Open a terminal with a large font in `~/sadame`, run `sudo -v` so sudo
   does not ask for a password on stage, and clear the screen.

## Demo script

Say what each command will do before pressing Enter.

1. **What does the recipe want?** Show the file briefly:

    ```sh
    less examples/12-omarchy-workstation/recipe.rb
    ```

2. **Plan.** Nothing changes yet; the missing file shows up as a diff:

    ```sh
    sudo sadame plan examples/12-omarchy-workstation
    ```

3. **Apply.** Only the missing file is written; everything else is
   reported unchanged:

    ```sh
    sudo sadame apply examples/12-omarchy-workstation
    ```

4. **Break something,** as anyone does on a laptop:

    ```sh
    sed -i 's/rebase = true/rebase = false/' ~/.gitconfig
    rm ~/.local/bin/update-system
    ```

5. **Drift catches it.** Point at the diff and at the exit status:

    ```sh
    sudo sadame drift examples/12-omarchy-workstation; echo $?
    ```

    Expected: `~ file[.../.gitconfig]` with `-rebase = false` and
    `+rebase = true`, `+ file[.../update-system]`, and `1`.

6. **Apply puts it back, drift agrees:**

    ```sh
    sudo sadame apply examples/12-omarchy-workstation
    sudo sadame drift examples/12-omarchy-workstation; echo $?   # 0
    ```

## If the demo fails

| What happens | What to do |
|---|---|
| sudo asks for a password | Type it; mention that sadame itself never asks, and that remote runs need passwordless sudo. |
| `drift` shows more than the two broken files | It is real drift on the laptop; read one difference out and continue with `apply`. |
| A package download hangs | Press Ctrl-C and switch to the recording below; the prepared apply should have avoided downloads. |
| The laptop or the projector fails | Play `docs/assets/demo.gif` (the same loop against a server), or show the captured sessions of this exact demo on the docs site: the Omarchy workstation guide, section "Did I break my laptop?". |
| Out of time | Skip step 1 and step 6's second command; the drift exit status is the point. |
