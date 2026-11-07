# Building sadame

Sadame is a C++17 program with [GNU Guile](https://www.gnu.org/software/guile/)
embedded. The core lives in `lib/sadame/*.cpp`; the languages users write
recipes, `hosts.scm` and `vars.scm` in are Guile Scheme, and the Scheme
parts of sadame itself (`lib/sadame/*.scm`) are compiled into the
executable as string literals, so the binary runs without the source tree.
This page explains how to build it, what the build produces, and what is
not covered yet.

## What you need

- a C++17 compiler (`g++` or `clang++`) and `make`
- Guile 3.0 with its development files: `guile-3.0-dev` on Debian and
  Ubuntu, `guile` on Arch and Alpine (`guile-dev`), `guile30-devel` on
  Fedora and Rocky, `guile` with Homebrew on macOS
- `pkg-config`, which finds Guile's compiler and linker flags

## Targets

| Command | Produces | Used for |
|---|---|---|
| `make` | `build/sadame` | everything |
| `make test` | `build/test_runner`, and runs it | the unit tests |
| `make clean` | removes `build/` | a fresh start |

`bin/sadame` is a small script that runs `build/sadame`, building it first
when it is missing, so `bin/sadame plan examples/01-hello` works from a
checkout.

When `pkg-config` cannot find Guile, give the flags yourself:

```sh
make GUILE_CFLAGS=-I/opt/guile/include/guile/3.0 \
     GUILE_LIBS="-L/opt/guile/lib -lguile-3.0 -lgc"
```

## How the build is put together

- **`Makefile`** compiles every `lib/**/*.cpp` and `tools/sadame/sadame.cpp`
  into `build/`, with header dependencies, and links them with Guile. The
  tests are built from `test/**/*_test.cpp` and linked with the same
  objects.
- **`build/embedded_scheme.cpp`** is generated from `lib/sadame/*.scm`:
  each file becomes a raw string literal, and `lib/sadame/scheme.cpp`
  evaluates them when it starts Guile. There is no other copy of the Scheme
  code, so editing a `.scm` file and running `make` is the whole loop.
- **`tools/sadame/sadame.cpp`** is `main`: it builds the argument list,
  starts Guile with `scm_with_guile`, runs the `CLI` and turns its return
  value into the exit status.

## Releases

The Ruby version shipped one statically linked mruby binary per platform.
A binary with Guile embedded depends on `libguile` and `libgc` (and their
dependencies) at run time unless Guile is linked statically, which needs a
Guile built for it. Producing and verifying release binaries, the
Homebrew formula, the AUR package and `install.sh` for the new build is not
done yet; the files `.github/workflows/build.yml`, `release.yml`,
`packaging/` and `script/build/` still describe the Ruby build.

## Not ported yet

These parts of the Ruby version are still in the tree as Ruby files and are
not built: push mode over SSH (`lib/sadame/push/`), the language server
(`lib/sadame/lsp/`) and `sadame report` (`lib/sadame/report_formats.rb`).
The commands that need them say so instead of running.
