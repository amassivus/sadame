# git

`git` keeps a checkout of a git repository at a revision: a tag, a branch
or a commit. The first apply clones the repository; later ones move the
checkout when the revision points somewhere else, such as a branch that
got new commits. Use it to deploy an application or a site from its
repository, or to keep a tool's source on a machine.

!!! note "New in 0.2.0"

## Minimal example

```ruby title="examples/resources/git/minimal.rb"
--8<-- "examples/resources/git/minimal.rb"
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `repository` | String | required | The URL to clone, as `git clone` takes it: HTTPS, SSH (`git@github.com:example/app.git`) or a local path. |
| `revision` | String | the remote's default branch | A tag, a branch or a full 40-character commit. |
| `user` | String | root | Run every git command as this user (through `su`), so the checkout belongs to them and their SSH keys and git configuration apply. |
| `state` | `:present` or `:absent` | `:present` | `:absent` removes the checkout with `rm -rf`. |
| `notifies` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on other resources when this one changes. See [Notifications](../recipes/notifications.md). |
| `subscribes` | `[:action, "type[name]"]`, optionally with `:immediately`, or a list of them | none | Actions to run on this resource when another one changes. |
| `tags` | Symbol, String, or an Array of them | none | Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](../recipes/tags.md). |

## How it works

- **plan** asks the remote which commit the revision names (`git
  ls-remote`; tags first, then branches, as git resolves a name) and
  compares it with the checkout's `HEAD`. A full commit needs no remote.
  This is why `plan` and `drift` need network access to the repository.
- **apply** clones with `git clone --no-checkout`, or fetches into an
  existing checkout, then runs `git checkout --force --detach COMMIT`. The
  checkout is on that commit, not on a branch.
- A checkout whose `origin` URL differs from `repository` gets the new URL
  (`git remote set-url`) and is fetched from there.
- An empty directory, such as one a [directory](directory.md) resource
  created for the user, is cloned into. A directory with other files in it
  is an error.

`git` must be installed: declare `package "git"` before. On a machine where
it is not installed yet, plan shows the revision as you wrote it; apply
resolves it once the package is in.

Git never asks for a password or passphrase during a run
(`GIT_TERMINAL_PROMPT=0`). Private repositories need credentials that work
without a prompt, such as a deploy key in the user's `~/.ssh` and the
server's host key in their `~/.ssh/known_hosts`.

## Scenarios

```ruby title="examples/resources/git/recipe.rb"
--8<-- "examples/resources/git/recipe.rb"
```

### A tagged release, cloned by a deploy user

```text
--8<-- "docs/transcripts/git.txt"
```

### Following a branch, and restarting on a new commit

With a branch as the revision, every apply moves the checkout to the
branch's latest commit, and a notification restarts the application only
when it moved:

```ruby
git "/srv/app",
    repository: "https://github.com/example/app.git",
    revision: "main",
    user: "deploy",
    notifies: [:restart, "service[app]"]
```

Pin a tag or a commit instead when every server must run the same code no
matter when it was last applied.

## Common mistakes

- **Local changes in the checkout.** Moving the checkout uses
  `checkout --force`, which discards changes to tracked files. Files git
  does not track, such as uploads or a `.env`, are kept. Keep anything
  that must survive outside the checkout.
- **Credentials that need a prompt.** A private HTTPS repository without
  stored credentials, or an SSH host key that is not in `known_hosts`,
  fails instead of waiting for an answer that never comes.
- **The wrong user for the key.** Without `user:`, git runs as root and
  uses root's `~/.ssh`. With `user: "deploy"`, the key must be deploy's.
- **Submodules.** They are not cloned or updated. Run
  `git submodule update --init` from an [exec](exec.md) resource that the
  `git` resource notifies.

## See also

- [package](package.md) to install git.
- [user](user.md) and [directory](directory.md) for the user who owns the
  checkout and the directory it lives in.
- [service](service.md) to restart the application when the checkout moves.
