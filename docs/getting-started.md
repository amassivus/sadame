# Getting started

This page takes you from a source checkout to your first `plan` and
`apply`: install sadame, write a one-line recipe, look at the plan, apply it,
and learn to read the diff sadame prints when a machine has drifted from its
recipe.

## Install from source

Release binaries are not published yet. Until they are, use a checkout of the
repository in one of two ways.

**Run it with Ruby.** Any Ruby 3.2 or newer works; nothing else is needed.

```sh
git clone https://github.com/enderkus/sadame.git
cd sadame
bin/sadame --version
```

**Build the single binary.** This compiles sadame with mruby into one file
with no runtime dependencies. You need a C compiler, `git`, Ruby and `rake`
for the build only.

```sh
git clone https://github.com/enderkus/sadame.git
cd sadame
rake build:native
sudo install -m 0755 build/host/bin/sadame /usr/local/bin/sadame
sadame --version
```

The rest of this page writes `sadame`; use `bin/sadame` if you run it from
the checkout.

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
$ sadame plan examples/01-hello
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

+ file[/tmp/sadame-hello.txt]
    state: absent -> present
    --- /dev/null
    +++ /tmp/sadame-hello.txt (desired)
    @@ -0,0 +1 @@
    +Hello from sadame!

Plan: 1 to create, 0 to update, 0 to remove, 0 to run, 0 unchanged.
```

`RECIPE` can be a file or a directory that contains `recipe.rb`. Without it,
sadame looks for `./recipe.rb`.

## Apply

`sadame apply` makes the same comparison, resource by resource, and changes
only what differs:

```text
$ sadame apply examples/01-hello
sadame 0.1.0.dev apply on local (Debian GNU/Linux 12 (bookworm))

changed    file[/tmp/sadame-hello.txt]
           state: absent -> present
           --- /dev/null
           +++ /tmp/sadame-hello.txt (desired)
           @@ -0,0 +1 @@
           +Hello from sadame!

Apply: 1 changed, 0 unchanged, 0 failed.
```

Run `plan` again and there is nothing left to do. That is what idempotent
means here: once the machine matches the recipe, running it again changes
nothing.

```text
$ sadame plan examples/01-hello
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

Plan: 0 to create, 0 to update, 0 to remove, 0 to run, 1 unchanged.
```

## Read the diff

Now change the file by hand, the way a colleague or a package upgrade might:

```text
$ echo 'Hello from someone else' > /tmp/sadame-hello.txt
$ sadame plan examples/01-hello
sadame 0.1.0.dev plan on local (Debian GNU/Linux 12 (bookworm))

~ file[/tmp/sadame-hello.txt]
    --- /tmp/sadame-hello.txt
    +++ /tmp/sadame-hello.txt (desired)
    @@ -1 +1 @@
    -Hello from someone else
    +Hello from sadame!

Plan: 0 to create, 1 to update, 0 to remove, 0 to run, 0 unchanged.
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

## JSON output

`--json` prints one JSON document instead, for scripts and CI:

```text
$ sadame plan examples/01-hello --json
{
  "format_version": 1,
  "sadame_version": "0.1.0.dev",
  "command": "plan",
  "host": "local",
  "platform": {
    "name": "Debian GNU/Linux 12 (bookworm)",
    "family": "debian",
    "package_manager": "apt"
  },
  "resources": [
    {
      "id": "file[/tmp/sadame-hello.txt]",
      "type": "file",
      "name": "/tmp/sadame-hello.txt",
      "status": "update",
      "changes": [
        {
          "attribute": "content",
          "sensitive": false,
          "diff": "--- current\n+++ desired\n@@ -1 +1 @@\n-Hello from someone else\n+Hello from sadame!\n"
        }
      ],
      "error": null
    }
  ],
  "notifications": [],
  "summary": {
    "create": 0,
    "update": 1,
    "remove": 0,
    "run": 0,
    "unchanged": 0,
    "failed": 0
  },
  "failed": false
}
```

## Exit status

| Status | Meaning |
|---|---|
| `0` | success; for `plan`, also when there are changes |
| `1` | a resource or notification failed |
| `2` | usage error, or the recipe, `vars.rb` or a template could not be loaded |

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

- [Recipe basics](recipes/basics.md): vars, `include_recipe` and templates.
- [Resources](resources/package.md): every resource and its options.
- `sadame --help` for the full command line.
