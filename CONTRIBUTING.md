# Contributing to Sadame

Thank you for helping. This guide covers setting up a development checkout,
running the tests, the rules for the C++ and Scheme code, and what a pull
request needs.

## Development setup

You need:

- a C++17 compiler, `make`, `pkg-config` and `git`;
- GNU Guile 3.0 with its development files (`guile-3.0-dev` on Debian and
  Ubuntu).

```sh
git clone https://github.com/enderkus/sadame.git
cd sadame
make                      # builds build/sadame
bin/sadame --version
```

## Running the tests

```sh
make test                      # builds build/test_runner and runs every test
build/test_runner Template     # only the tests whose "Suite.name" contains this
```

`make` builds `build/sadame`, the single executable with Guile embedded.
Releases are described in
[Building sadame](https://enderkus.github.io/sadame/contributing/building/).

Tests never need root: resources are tested against `FakeShell`
(`test/support/fake_shell.hpp`), which records commands and returns stubbed
results.

The Docker, push-mode and VM test layers are Ruby scripts written for the
earlier mruby build and have not been adapted yet.
[Testing](https://enderkus.github.io/sadame/contributing/testing/)
explains all three layers.

## Writing C++ and Scheme code

The logic is C++17 under `lib/sadame/`; the recipe, hosts, vars and
template languages are Guile Scheme, and the Scheme modules
(`lib/sadame/*.scm`) are compiled into the binary. Two rules keep the
boundary safe:

- Everything Scheme can call lives in `lib/sadame/scheme.cpp`. A new
  primitive runs its body inside `guarded()`, so a C++ exception becomes a
  Scheme error after its frames are gone and never unwinds through Guile.
- Run commands and read or write files of the managed machine only through
  `Shell`, so tests can swap it and `sadame validate` can refuse it.

The rest is in
[Architecture](https://enderkus.github.io/sadame/contributing/architecture/#where-c-and-scheme-meet).

## Style

- Clear names, small functions, plain classes. Comments only where the code
  needs a word of explanation.
- Every resource reads the current state before acting and does nothing when
  it matches the desired state.
- Errors meant for users are `sadame::Error` subclasses with a message that
  says what to do.

## Documentation and examples

Documentation is part of every change:

- A new feature comes with a page (or a section) in `docs/` following the
  feature page shape: what and why, a minimal example, an option table,
  realistic scenarios with real output, common mistakes, see also.
- Every recipe shown in the docs lives under `examples/` and is embedded
  with `--8<-- "examples/..."`. `test/unit/examples_test.cpp` loads and
  validates every example for every distribution it supports and checks
  that every `examples/` path mentioned in the docs exists.
- Terminal sessions in the docs are captured, not typed. Each one is
  defined in `script/transcripts/scenarios.rb`, written to
  `docs/transcripts/`, and embedded with
  `--8<-- "docs/transcripts/NAME.txt"`. The capture scripts are Ruby tooling
  for the earlier build and have not been adapted yet; when a change alters
  output, update the affected transcripts by hand from a real run.

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
- A pull request passes `make test` and `mkdocs build --strict`, and updates
  `CHANGELOG.md` under "Unreleased".
- A new feature or resource comes with its docs page and a tested example
  under `examples/`; the pull request template lists what that means.

## License

By contributing you agree that your contributions are licensed under the
MIT License.
