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

`rake build:native` builds a development binary into
`build/host/bin/sadame`. Release binaries, static Linux builds through
Docker and the macOS builds, are described in
[Building sadame](https://enderkus.github.io/sadame/contributing/building/).

Tests never need root: resources are tested against `FakeShell`
(`test/support/fake_shell.rb`), which records commands and returns stubbed
results.

Two more layers run sadame for real, with Docker:

```sh
rake build:linux-arm64                  # or linux-amd64: the binary under test
rake "test:docker[debian,arm64]"        # every example in fresh containers booting systemd
rake test:push                          # push mode against SSH servers in containers
```

CI runs both on every pull request, for five distributions and two
architectures. A third layer runs on the maintainer's virtual machines and
is not part of CI. [Testing](https://enderkus.github.io/sadame/contributing/testing/)
explains all three.

## Writing code for mruby

Release builds are a single mruby binary, so everything under `lib/` must
run on mruby with only the gems listed in `build_config.rb`:

- Never call `require` in `lib/`. To add a file, list it with
  `require_relative` in `lib/sadame.rb`; the mruby build reads that list to
  compile the same files in the same order.
- No standard library (JSON, YAML, ERB, Open3, FileUtils, ...). Sadame has
  small replacements: `Sadame::JsonWriter`, `Sadame::Template`,
  `Sadame::Shell.escape`.
- Run commands and read files only through `Sadame::Shell`.
- In a `rescue` clause, re-raise with `raise e`, not a bare `raise`.

The full list of pitfalls, with what to use instead, is in
[Architecture](https://enderkus.github.io/sadame/contributing/architecture/#code-that-must-run-on-mruby).
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

CI also checks every internal link and anchor of the built site with
[lychee](https://lychee.cli.rs/). The same check locally, with Docker:

```sh
docker run --rm -v "$PWD/site:/web/sadame:ro" lycheeverse/lychee --offline \
  --include-fragments --index-files index.html --root-dir /web /web/sadame
```

## Reporting bugs and proposing features

Use the issue templates: a bug report asks for the version, the command,
a small recipe and the output with `--no-color`; a new resource proposal
asks how the resource reads the current state and changes it on each
distribution. Security problems: please do not open a public issue; write
to the maintainer through the contact on their GitHub profile.

## Commits and pull requests

- Small, focused commits using
  [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(resource): add cron resource`, `fix(file): keep owner on rewrite`,
  `docs(exec): explain guard order`.
- Keep the history as it is; do not rewrite published commits.
- A pull request passes `rake test` on both runtimes and
  `mkdocs build --strict`, and updates `CHANGELOG.md` under "Unreleased".
- A new feature or resource comes with its docs page and a tested example
  under `examples/`; the pull request template lists what that means.

## License

By contributing you agree that your contributions are licensed under the
MIT License.
