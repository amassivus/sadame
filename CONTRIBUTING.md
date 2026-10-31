# Contributing to Sadame

Thank you for helping. This guide covers setting up a development checkout,
running the tests on both Ruby runtimes, the rules that keep the code
working under mruby, and what a pull request needs.

## Development setup

You need:

- Ruby 3.2 or newer and Bundler, for running sadame from source and for the
  test suite;
- a C compiler, `git` and `bison`, for building the mruby binary.

```sh
git clone https://github.com/enderkus/sadame.git
cd sadame
bundle install
```

## Running the tests

The same test files run under CRuby (with minitest) and inside the mruby
build (with mruby-mtest). CI requires both to pass.

```sh
bundle exec rake test:cruby   # fast, no compiler needed
bundle exec rake test:mruby   # builds mruby with sadame into build/, then runs the suite
bundle exec rake test         # both
```

`rake build:native` builds the binary alone, into `build/host/bin/sadame`.
The first build clones mruby into `vendor/` and its gems into
`build/repos/`; both are ignored by git.

Tests never need root: resources are tested against `FakeShell`
(`test/support/fake_shell.rb`), which records commands and returns stubbed
results.

## Writing code for mruby

Release builds are a single mruby binary, so everything under `lib/` must
run on mruby with only the gems listed in `build_config.rb`. In practice:

- Never call `require` in `lib/`. To add a file, list it with
  `require_relative` in `lib/sadame.rb`; the mruby build reads that list to
  compile the same files in the same order.
- No standard library: no JSON, YAML, Open3, FileUtils, ERB, Shellwords,
  OptionParser or Net::*. Sadame has small replacements
  (`Sadame::JsonWriter`, `Sadame::Template`, `Sadame::Shell.escape`).
- Run commands only through `Sadame::Shell`.
- Avoid methods mruby lacks without extra gems, for example `Integer#zero?`,
  `#even?` and `#odd?` (use `== 0`), enumerators without a block
  (`map.with_index`, `each_slice(2).to_a`), `catch`/`throw`,
  `File.basename(path, ext)` with two arguments, `String#unpack`, and
  backticks.
- In a `rescue` clause, re-raise with `raise e`, not a bare `raise`: mruby
  3.4 raises a new `RuntimeError` for a bare `raise`.
- Do not rely on `inspect` output in messages users see; its format differs
  between runtimes.

If you think a new mruby gem is needed, explain why in the commit that adds
it to `build_config.rb`.

## Style

- Clear names, small methods, plain classes. No metaprogramming beyond what
  the recipe DSL needs.
- Every resource reads the current state before acting and does nothing when
  it matches the desired state.
- Errors meant for users are `Sadame::Error` subclasses with a message that
  says what to do.

## Documentation and examples

Documentation is part of every change:

- A new feature comes with a page (or a section) in `docs/` following the
  feature page shape: what and why, a minimal example, an option table,
  realistic scenarios with real output, common mistakes, see also.
- Every recipe shown in the docs lives under `examples/` and is embedded
  with `--8<-- "examples/..."`. `test/unit/examples_test.rb` loads, plans
  and applies every example against a fake machine and checks that every
  `examples/` path mentioned in the docs exists.
- Terminal sessions in the docs are captured, not typed. Each one is
  defined in `script/transcripts/scenarios.rb`, run in a fresh Docker
  container by `rake docs:transcripts` (or `SCENARIO=name rake
  docs:transcripts` for one), written to `docs/transcripts/`, and embedded
  with `--8<-- "docs/transcripts/NAME.txt"`. Short excerpts, such as a diff
  shown on its own, are copied from those files. When a change alters
  output, regenerate the transcripts and commit them with the change.

Build the site locally with:

```sh
python3 -m venv .venv
.venv/bin/pip install -r docs/requirements.txt
.venv/bin/mkdocs build --strict
.venv/bin/mkdocs serve
```

## Commits and pull requests

- Small, focused commits using
  [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(resource): add cron resource`, `fix(file): keep owner on rewrite`,
  `docs(exec): explain guard order`.
- Keep the history as it is; do not rewrite published commits.
- A pull request passes `rake test` on both runtimes and
  `mkdocs build --strict`, and updates `CHANGELOG.md` under "Unreleased".

## License

By contributing you agree that your contributions are licensed under the
MIT License.
