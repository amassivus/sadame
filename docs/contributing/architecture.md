# Architecture

Sadame is a small Ruby program that has to run in two places: on CRuby
during development and tests, and compiled into a single mruby binary for
users. This page maps the code, follows one run through it, lists the rules
that keep the code working on mruby, and walks through the two most common
extensions: a new resource and a new package manager.

## Module map

All code lives in `lib/sadame/`. `lib/sadame.rb` lists the files in load
order; the mruby build compiles the same list.

| File | Responsibility |
|---|---|
| `cli.rb` | Parses arguments, loads vars and the recipe, runs a command, returns the exit status. `Sadame.main` is the entry point of the binary. |
| `vars.rb` | Loads `vars.rb`, parses `--var`, merges layers. |
| `recipe.rb` | The recipe DSL: `package`, `file`, ..., `include_recipe`, `vars`, `platform`. Evaluates recipe files with `instance_eval`. |
| `resource_collection.rb` | The ordered resources of a run, duplicate detection, and the notification index. |
| `resource.rb` | Base class: option validation, `desired` / `current` / `diff` / `apply`, notification actions. |
| `resources/*.rb` | One class per resource type. |
| `notification.rb` | Parses `notifies:` and `subscribes:` entries. |
| `runner.rb` | Runs `plan`, `drift` and `apply` over a collection; queues and runs notifications. |
| `report.rb` | The result of a run: entries, notification runs, counts, exit status, JSON shape. |
| `output.rb` | Renders a report as text (as it happens) or as JSON (at the end). |
| `diff.rb` | Attribute changes and unified diffs (Myers' algorithm). |
| `template.rb` | The ERB-compatible template engine. |
| `host.rb` | The machine being configured: its shell plus facts read once (platform, package manager, systemd). |
| `platform.rb` | Reads `/etc/os-release`; maps distributions to families and package managers. |
| `package_managers/*.rb` | apt, dnf, apk and pacman: the command lines for query, install and remove. |
| `path_stat.rb` | Type, mode, owner and group of a path, from `stat`. |
| `shell.rb` | The only place commands run and files are read or written. |
| `json_writer.rb` | JSON generation, identical on both runtimes. |
| `errors.rb` | Error classes and recipe error locations. |

## One run, step by step

```mermaid
flowchart TD
    cli["CLI: parse arguments"] --> vars["Vars: vars.rb + --var"]
    vars --> recipe["Recipe.load: evaluate recipe files"]
    recipe --> collection["ResourceCollection<br/>+ linked notifications"]
    collection --> runner["Runner: plan / drift / apply"]
    runner --> resource["Resource#diff<br/>desired vs current"]
    resource --> shell["Shell: commands, files"]
    runner --> report["Report"]
    report --> output["Output: text or JSON"]
    report --> status["exit status"]
```

1. `CLI` parses the arguments and finds the recipe and `vars.rb`.
2. `Recipe.load` evaluates the recipe in a `Recipe` object. Each DSL call
   builds a resource, which validates its options right away, and adds it
   to the `ResourceCollection`. After the last file, the collection links
   notifications and checks that every target exists.
3. `Runner` walks the collection. For each resource it calls `diff`, which
   compares `desired` with `current`. `current` reads the machine through
   the `Shell` of the `Host`; nothing else touches the system.
4. For `apply`, a non-empty diff is passed to the resource's `apply`, and
   the notifications it triggers run immediately or are queued.
5. Each result goes to a `Report` and to the `Output`, which prints text as
   the run progresses or JSON at the end. `Report#exit_status` becomes the
   process exit status.

## Code that must run on mruby

Release builds are mruby, so code in `lib/` may only use the language and
the gems in `build_config.rb`. CI runs the whole test suite on both
runtimes, which catches most mistakes, but these are the ones that come up:

| Do not use | Because | Use instead |
|---|---|---|
| `require`, `require_relative` in `lib/` | mruby has no loader; the build compiles a fixed file list | add the file to `lib/sadame.rb` |
| JSON, YAML, ERB, Open3, FileUtils, Shellwords, OptionParser, Set, Net::* | no standard library | `JsonWriter`, `Template`, `Shell`, `Shell.escape`, plain loops |
| `Integer#zero?`, `#even?`, `#odd?`, `#positive?` | not in the included gems | `== 0`, `% 2` |
| enumerators without a block: `each_slice(2).to_a`, `map.with_index`, `each_char.map` | mruby's enumerators need fibers, which are not built in | blocks, `each_with_index` with a block, `chars` |
| `catch` / `throw` | not built in | return values |
| `File.basename(path, ".rb")` | only one argument is supported | `File.basename(path).delete_suffix(".rb")` |
| bare `raise` in a `rescue` clause | mruby 3.4 raises a new `RuntimeError` | `rescue Foo => e` and `raise e` |
| backticks, `system`, `Process.spawn` | they bypass `Shell`, and spawn does not exist | `Shell#run`, `Shell#run!` |
| `inspect` output in user-facing messages | its format differs between runtimes | format values explicitly |
| `instance_eval` with a string at the top level of a script | mruby then defines later top-level methods on the wrong object | call it inside a method |

Strings are byte strings in the mruby build (`"é".size` is 2), which only
matters when counting characters for alignment.

## Adding a resource

This section builds a `cron` resource that manages one job as a file in
`/etc/cron.d`. Sadame does not ship it; the code below is kept in
`test/unit/tutorial_cron_test.rb`, where it is compiled and tested on both
runtimes like the real resources.

### 1. Decide what the desired state is

A resource is a set of attributes whose current value can be read and
compared. For a cron job that is whether the file exists (`state`) and its
exact text (`content`). Using the attribute name `content` means plan output
and JSON show changes as a unified diff, like the `file` resource does.

### 2. Write the class

In a real change this goes into `lib/sadame/resources/cron.rb`:

```ruby
--8<-- "test/unit/tutorial_cron_test.rb:resource"
```

What the base class does for you:

- `allowed_options` is checked when the recipe loads: an unknown option
  fails before anything runs. `notifies:` and `subscribes:` are always
  allowed.
- `validate` runs right after, for option values.
- `diff` compares `desired` with `current`, attribute by attribute. Only
  keys present in `desired` are compared.
- `plan_action` turns a `state` change from `"absent"` into a create and a
  change to `"absent"` into a remove.
- `apply` is only called with a non-empty diff.

Two rules to keep: read the machine only through `shell` (never `File`
directly), and make `apply` change only what differs.

### 3. Register it

Add the file to `lib/sadame.rb`, after `resource_collection` and before
`recipe`:

```ruby
require_relative "sadame/resources/cron"
```

and add the DSL method to `Sadame::Recipe` in `lib/sadame/recipe.rb`. The
tutorial does it in a subclass to leave the real DSL alone:

```ruby
--8<-- "test/unit/tutorial_cron_test.rb:recipe"
```

A recipe can now declare cron jobs:

```ruby title="test/fixtures/recipes/tutorial_cron/recipe.rb"
--8<-- "test/fixtures/recipes/tutorial_cron/recipe.rb"
```

### 4. Test it without root

Tests run against `FakeShell`, which records commands and keeps files in
memory, so they need no root and touch nothing. Cover creating, the
no-change case, an update, removal and validation:

```ruby
--8<-- "test/unit/tutorial_cron_test.rb:tests"
```

Run `bundle exec rake test` to check both runtimes.

### 5. Document it

1. Write `docs/resources/cron.md` in the feature page shape: what and why,
   minimal example, option table, scenarios, common mistakes, see also.
2. Put every recipe the page shows in a new `cron` directory under
   `examples/resources/` and add them to `EXAMPLES` in
   `test/unit/examples_test.rb`.
3. Add a scenario to `script/transcripts/scenarios.rb` that runs the
   examples, run `SCENARIO=cron rake docs:transcripts`, and embed the
   transcripts.
4. Add the page to `mkdocs.yml` and an entry to `CHANGELOG.md`.

## Adding a package manager

This section adds zypper, for openSUSE. Like the cron resource, the code is
kept in `test/unit/tutorial_zypper_test.rb`.

### 1. Write the class

A package manager only provides three command lines; `Base` runs them and
turns exit statuses into results. In a real change this goes into
`lib/sadame/package_managers/zypper.rb`:

```ruby
--8<-- "test/unit/tutorial_zypper_test.rb:manager"
```

Override `installed?` when the query's exit status is not enough, as `Apt`
does with `dpkg-query`, and `install` when the index needs refreshing, as
`Apt` does with `apt-get update`.

### 2. Register it

- Add `require_relative "sadame/package_managers/zypper"` to
  `lib/sadame.rb`, before `sadame/package_managers`.
- Add `"zypper" => Zypper` to `PackageManagers::ALL` in
  `lib/sadame/package_managers.rb`.
- Teach `Platform` the family: add
  `"suse" => %w[opensuse-leap opensuse-tumbleweed sles]` to `FAMILY_IDS`
  and `"suse" => "zypper"` to `PACKAGE_MANAGERS` in
  `lib/sadame/platform.rb`.

### 3. Test it

Add the distribution's real `/etc/os-release` as a fixture under
`test/fixtures/os-release/` (copy it from the official container image) and
a platform test for it. Then test the exact command lines:

```ruby
--8<-- "test/unit/tutorial_zypper_test.rb:tests"
```

### 4. Document it

Add a row to the command table in `docs/resources/package.md`, capture a
transcript on that distribution, and update `CHANGELOG.md`.

## Common mistakes

- **Reading files with `File` in a resource.** It works on CRuby and in
  production, but tests then read your machine instead of `FakeShell`.
  Use `shell.read_file`.
- **Forgetting `lib/sadame.rb`.** Neither runtime loads a file that is not
  listed there: CRuby follows its `require_relative` lines and the mruby
  build compiles exactly those files.
- **Changing output without regenerating transcripts.** Run
  `rake docs:transcripts` and commit the changed files in `docs/transcripts/`.

## See also

- [Building sadame](building.md)
- [Contributing](index.md)
