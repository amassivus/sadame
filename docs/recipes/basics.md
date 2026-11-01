# Recipe basics

A recipe is a Ruby file that declares the desired state of a machine as a
list of resources. Sadame evaluates the file from top to bottom, collects the
resources in the order they appear, and then plans or applies them in that
order. Because the recipe is ordinary Ruby, loops, conditionals and helper
methods need no special syntax. This page covers how a recipe directory is
laid out, where `vars` come from, how `include_recipe` splits a recipe into
files, and how templates work.

## A complete example

The example used on this page lives in `examples/basics`:

```text
examples/basics/
  recipe.rb                 # entry point
  vars.rb                   # default vars
  parts/motd.rb             # included recipe
  parts/templates/motd.erb  # template used by parts/motd.rb
```

```ruby title="examples/basics/recipe.rb"
--8<-- "examples/basics/recipe.rb"
```

```ruby title="examples/basics/vars.rb"
--8<-- "examples/basics/vars.rb"
```

```ruby title="examples/basics/parts/motd.rb"
--8<-- "examples/basics/parts/motd.rb"
```

```erb title="examples/basics/parts/templates/motd.erb"
--8<-- "examples/basics/parts/templates/motd.erb"
```

Planned on a fresh Debian 12 machine:

```text
--8<-- "docs/transcripts/basics-plan.txt"
```

## The recipe file

- Each resource is a method call: `type "name", option: value, ...`. The
  name identifies the resource: a package name, a path, a command, a user
  name. Together they form the resource id, `type[name]`, which shows up in
  output and is used by `notifies:`.
- An id may appear only once. Declaring `package "git"` twice is an error
  that names the file and line.
- Options are checked when the recipe loads. A misspelled option fails the
  whole run, with exit status 2, before anything is changed:

  ```text
  --8<-- "docs/transcripts/basics-unknown-option.txt"
  ```

- Ruby code in a recipe runs every time the recipe is loaded, for `plan` as
  well as `apply`. Use it to decide *what* to declare; make changes only
  through resources.

Besides the resources, a recipe can use:

| Name | What it is |
|---|---|
| `vars` | Hash of variables with symbol keys (see below) |
| `platform.family` | `"debian"`, `"rhel"`, `"alpine"`, `"arch"` or `nil` |
| `platform.package_manager` | `"apt"`, `"dnf"`, `"apk"`, `"pacman"` or `nil` |
| `platform.id`, `platform.version`, `platform.codename`, `platform.name` | `ID`, `VERSION_ID`, `VERSION_CODENAME` and `PRETTY_NAME` from `/etc/os-release` |
| `facts[:cpus]`, `facts[:memory_mb]`, `facts[:ipv4]` and more | what the machine has, read from it; see [Facts](facts.md) |
| `host_name`, `host_groups` | the host's name and groups from the inventory; see [Inventory](inventory.md#using-groups-in-recipes) |
| `include_recipe "path"` | evaluate another recipe file |

For example, a package whose name differs between distributions:

```ruby title="examples/resources/package/by_family.rb"
--8<-- "examples/resources/package/by_family.rb"
```

## vars

`vars` is a plain Hash with symbol keys. In this release it is filled from
two places, highest precedence first:

| Precedence | Source | Example |
|---|---|---|
| 1 (highest) | `--var key=value` on the command line, repeatable | `--var workers=8` |
| 2 | `vars.rb` next to the recipe | `{ workers: 4 }` |

`vars.rb` is Ruby whose last expression is a Hash; it can compute values,
for example read an environment variable. Keys may be symbols or strings and
always become symbols.

Values given with `--var` are strings, except:

| Given | Becomes |
|---|---|
| `true`, `false` | `true`, `false` |
| digits with an optional leading `-`, and no leading zero | Integer: `8`, `-2`, `0` |
| anything else | String: `"0644"`, `"1.5"`, `"web01"` |

Adding a maintenance window for one run changes the template output:

```text
--8<-- "docs/transcripts/basics-plan-maintenance.txt"
```

## include_recipe

`include_recipe "parts/motd"` evaluates `parts/motd.rb`. The path is
relative to the file that contains the call, and `.rb` is optional. The
included file shares `vars` and adds its resources at that point in the
order. A file included more than once is evaluated only the first time, so
two roles can both include a common base recipe.

Templates and source files used by an included recipe are looked up relative
to *that* file, not the entry point. That keeps a directory such as `parts/`
or `roles/web/` self-contained.

## Templates

`file` with `template:` renders an ERB template. Sadame implements the
commonly used part of ERB itself, because the single binary cannot ship
Ruby's ERB library:

| Tag | Effect |
|---|---|
| `<%= expression %>` | inserts the result of `expression` |
| `<% code %>` | runs Ruby code: `if`, `each`, assignments |
| `<%# comment %>` | produces nothing |
| `-%>` | at the end of any tag: also removes the newline that follows |
| `<%-` | at the start of a tag: also removes the indentation before it |
| `<%%` | a literal `<%` |

Inside a template, `vars` is the run's vars, `locals` is the Hash given
to the `file` resource's `locals:` option, and `facts` are the machine's
[facts](facts.md). Nothing else from the recipe is visible.

The template is looked up in the recipe's directory first, then in its
`templates/` subdirectory. `parts/motd.rb` above uses `motd.erb`, found at
`parts/templates/motd.erb`.

After `apply`, changing a var shows exactly which lines of the rendered file
change:

```text
--8<-- "docs/transcripts/basics-plan-contact.txt"
```

An error in a template fails that resource and names the template and
line. Here `templates/app.conf.erb` contains `port = <%= port %>`:

```text
--8<-- "docs/transcripts/basics-template-error.txt"
```

Here the template used `port` instead of `locals[:port]`. The wording after
the line number comes from the Ruby runtime and differs slightly between the
single binary and CRuby.

## Common mistakes

- **String keys in `vars`.** Keys are always symbols: `vars[:team]`, not
  `vars["team"]`, which returns `nil`.
- **Blank lines from control tags.** `<% if x %>` on its own line leaves an
  empty line in the output, as in ERB. End such tags with `-%>`.
- **Expecting `--var port=08080` to be a number.** Leading zeros keep a
  value a string, so modes like `0644` survive.
- **Side effects in Ruby code.** `File.write` or backticks at the top of a
  recipe run during `plan` too. Use `exec` with a guard instead.
- **Templates next to the wrong file.** A template used in `roles/web.rb`
  belongs in `roles/` or `roles/templates/`, not next to the entry recipe.

## See also

- [file](../resources/file.md) for `template:`, `source:` and `locals:`.
- [exec](../resources/exec.md) for commands with guards.
- [Getting started](../getting-started.md) for reading plan output.
