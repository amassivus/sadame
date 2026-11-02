# Getting started

This page takes you from installing sadame to your first `plan` and
`apply`: install it, write a one-line recipe, look at the plan, apply it,
and learn to read the diff sadame prints when a machine has drifted from its
recipe.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
sadame --version
```

The examples on this page are in the repository; clone it to follow along:

```sh
git clone https://github.com/enderkus/sadame.git
cd sadame
```

The [Install](install.md) page has the other ways to install, including
running sadame from the checkout with Ruby 3.2 or newer (`bin/sadame`).

## Your first recipe

A recipe is a Ruby file that declares resources: packages, files,
directories, services, commands and users. The smallest one has a single
resource:

```ruby title="examples/01-hello/recipe.rb"
--8<-- "examples/01-hello/recipe.rb"
```

It writes to `/tmp`, so it works without root.

## Plan

`sadame plan` reads the current state of everything the recipe declares and
prints what `apply` would change. It changes nothing.

```text
--8<-- "docs/transcripts/getting-started-plan.txt"
```

`RECIPE` can be a file or a directory that contains `recipe.rb`. Without it,
sadame looks for `./recipe.rb`.

## Apply

`sadame apply` makes the same comparison, resource by resource, and changes
only what differs:

```text
--8<-- "docs/transcripts/getting-started-apply.txt"
```

Run `plan` again and there is nothing left to do. That is what idempotent
means here: once the machine matches the recipe, running it again changes
nothing.

```text
--8<-- "docs/transcripts/getting-started-plan-again.txt"
```

## Read the diff

Now change the file by hand, the way a colleague or a package upgrade might:

```text
--8<-- "docs/transcripts/getting-started-edited.txt"
```

Each resource that would change gets a header line with a symbol and the
resource's id, `type[name]`:

| Symbol | Meaning |
|---|---|
| `+` | create: the resource does not exist yet |
| `~` | update: it exists but some attributes differ |
| `-` | remove: the recipe says `state: :absent` and it exists |
| `!` | run: an `exec` command whose guards say it must run |
| `x` | failed: the current state could not be read; the error follows |

Below the header, each differing attribute is shown as `current -> desired`.
File content is shown as a unified diff, the same format as `diff -u` and
`git diff`: `---` is the file on disk, `+++` is what the recipe wants. In a
terminal, removed lines are red and added lines green:

```diff
--- /tmp/sadame-hello.txt
+++ /tmp/sadame-hello.txt (desired)
@@ -1 +1 @@
-Hello from someone else
+Hello from sadame!
```

Colors are turned off when output is not a terminal, with `--no-color`, or
when the `NO_COLOR` environment variable is set.

The last line counts resources by what would happen to them. Unchanged
resources are counted but not listed.

## Check for drift

`sadame drift` reads the same state as `plan`, but its exit status says
whether the machine still matches the recipe: `0` when it does, `1` when it
has drifted. That makes it the command for scripts, cron jobs and CI:

```text
--8<-- "docs/transcripts/getting-started-drift.txt"
```

[Plan, apply, drift](concepts/plan-apply-drift.md) explains when to use
which, and [Drift in CI](guides/drift-in-ci.md) runs the check on a
schedule.

## JSON output

`--json` prints one JSON document instead, for scripts and CI. Every field
is described in the [JSON output reference](reference/json-output.md):

```text
--8<-- "docs/transcripts/getting-started-json.txt"
```

## Exit status

| Status | `plan` | `apply` | `drift` |
|---|---|---|---|
| `0` | the plan was computed, with or without changes | every resource and notification succeeded | the machine matches the recipe |
| `1` | not used | a resource or notification failed | the machine differs from the recipe |
| `2` | usage or recipe error, or the state of a resource could not be read | usage or recipe error | usage or recipe error, or the state of a resource could not be read |

## Your own project

`sadame init` writes the files a project starts from: a recipe with one
resource, `vars.rb`, an inventory with examples to uncomment, and a
template. `sadame validate` checks the recipe without touching a machine:

```text
--8<-- "docs/transcripts/init.txt"
```

Add `--ci github` or `--ci gitlab` to also get a daily
[drift check](guides/drift-in-ci.md) for your CI, and set up your editor
with [`sadame lsp`](guides/editors.md) to see mistakes as you type.

## Common mistakes

- **Running without root.** Most real recipes install packages or write
  under `/etc`. Run them with `sudo sadame apply ...`; `plan` usually needs
  root too, to read files only root can read.
- **Expecting `apply` to undo things it does not manage.** Sadame only
  compares what the recipe declares. Deleting a resource from a recipe does
  not remove it from the machine; declare it with `state: :absent` instead.
- **Treating `plan` as a guarantee.** `plan` compares each resource with the
  machine as it is now. During `apply`, earlier resources change the machine
  (a package creates a user, a file a service needs), so later resources are
  compared again right before they run.

## See also

- [Sadame: Configuration Management Made Simple](https://enderkus.github.io/sadame-beginner-guide/), the
  beginner's guide: a free book that goes from a first recipe to a whole
  fleet, with a practice lab to follow along.
- [Plan, apply, drift](concepts/plan-apply-drift.md): the three commands
  and their exit statuses.
- [Recipe basics](recipes/basics.md): vars, `include_recipe` and templates.
- [Remote hosts](guides/remote-hosts.md): run the same recipe on other
  machines over SSH, with an [inventory](recipes/inventory.md).
- [Resources](resources/package.md): every resource and its options.
- `sadame --help` for the full command line.
