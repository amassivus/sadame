# Building sadame

Sadame's Ruby code in `lib/` is compiled together with
[mruby](https://mruby.org) into one executable. This page explains the
build targets, what each produces, how the release binaries are checked
before they are published, and how to fix common build problems.

## Overview

| Task | Runs on | Produces | Used for |
|---|---|---|---|
| `rake build:native` | any Unix | `build/host/bin/sadame` and `build/host/bin/mruby` | development; `rake test:mruby` |
| `rake build:linux-amd64` | any machine with Docker | `dist/sadame-linux-amd64` | releases |
| `rake build:linux-arm64` | any machine with Docker | `dist/sadame-linux-arm64` | releases |
| `rake build:macos` | macOS with Xcode command line tools | `dist/sadame-darwin-arm64`, `dist/sadame-darwin-amd64` | releases |
| `rake verify:linux-amd64`, `verify:linux-arm64` | Docker | runs the binary in several distributions | releases |
| `rake verify:macos` | macOS | runs both macOS binaries | releases |
| `rake checksums` | any | `dist/SHA256SUMS` | releases |

The first build clones mruby 3.4.0 into `vendor/` and the third-party gems
into `build/*/repos/`. Both directories are ignored by git.

## How the build is put together

- **`build_config.rb`** is mruby's build configuration. `sadame_gems`
  lists every mruby gem in the binary; adding one needs a reason in the
  commit message. The `SADAME_TARGET` environment variable selects one of
  four configurations: `development` (debug information, plus an mruby
  interpreter with mruby-mtest for the tests), `linux-static`,
  `darwin-arm64` and `darwin-amd64`. The Rakefile sets it.
- **`build_config.rb.lock`** pins each third-party gem to a commit. mruby
  writes it on the first build and reads it afterwards, so every build uses
  the same code. Commit it when it changes.
- **`mrbgem.rake`** turns sadame into an mruby gem. It reads the
  `require_relative` lines of `lib/sadame.rb` and compiles those files in
  that order, so CRuby and mruby load the same code the same way.
- **`tools/sadame/sadame.c`** is the `main` function: it builds `ARGV`,
  calls `Sadame.main` and turns the returned Integer into the exit status.

## Static Linux binaries

`rake build:linux-amd64` and `rake build:linux-arm64` build inside an
Alpine Linux container of the target architecture
(`script/build/alpine.Dockerfile`). Alpine uses musl libc, which links
statically without the problems glibc has with static binaries, so the
result runs on any Linux distribution of that architecture. The container
runs as your user, so the files in `build/` and `dist/` stay yours, and the
binary is stripped with the container's `strip`.

Building for the other architecture than your machine's needs an emulator
registered with Docker. Docker Desktop and OrbStack include one; on a Linux
machine, register QEMU once:

```sh
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

Emulated builds are slower, especially under QEMU.

## macOS binaries

`rake build:macos` compiles both macOS binaries on one Mac with clang's
`-arch` flag, targeting macOS 11 and newer. It uses mruby's cross-build
support, so the `mrbc` compiler used during the build runs natively.

## Verification

Before a binary is published, it has to run unmodified in the systems it is
meant for. `rake verify:linux-amd64` and `rake verify:linux-arm64` start
each of these images with the binary mounted, and run
`script/build/smoke-test.sh` inside it:

| Image | amd64 | arm64 |
|---|---|---|
| `ubuntu:24.04` | yes | yes |
| `debian:12` | yes | yes |
| `rockylinux/rockylinux:9` | yes | yes |
| `alpine:3.20` | yes | yes |
| `archlinux:latest` | yes | no arm64 image exists |

The smoke test runs `--version`, then `plan`, `apply` and `drift` on
`examples/01-hello`, edits the managed file, and checks that `drift` now
exits `1` and reports `"drift": true` in JSON. `rake verify:macos` runs the
same test with both macOS binaries; the Intel one runs through Rosetta when
it is installed.

## Continuous integration and releases

- **`.github/workflows/build.yml`** builds `linux-amd64` on an x86_64
  runner, `linux-arm64` on an ARM64 runner and both macOS binaries on a
  macOS runner. A separate job then registers QEMU with
  `tonistiigi/binfmt`, checks with `file` that both Linux binaries are
  statically linked, and runs the verification for both architectures on
  the x86_64 runner: the arm64 binary runs under emulation there. A last
  job serves the binaries over HTTP and runs `install.sh` against them,
  once with correct checksums and once with a wrong one, which must fail.
- **`ci.yml`** runs that workflow on every push and pull request, after the
  test jobs.
- **`release.yml`** runs on a `v*` tag. After the build workflow passes, it
  checks that the tag matches `Sadame::VERSION`, writes `SHA256SUMS`, takes
  the release notes from the matching section of `CHANGELOG.md`, and
  creates the GitHub release with all files attached. Started by hand from
  the Actions tab, it does everything except publishing and keeps the
  assembled files as a workflow artifact instead.

To publish a release:

1. Set `VERSION` in `lib/sadame/version.rb` and move the `Unreleased`
   entries of `CHANGELOG.md` under a heading such as
   `## [0.1.0] - 2026-11-15`.
2. Commit, then tag and push: `git tag v0.1.0 && git push origin v0.1.0`.

## Building a release locally

```sh
rake build:linux-amd64 build:linux-arm64 verify:linux-amd64 verify:linux-arm64
rake build:macos verify:macos      # on a Mac
rake checksums
script/build/test-install.sh       # install.sh against dist/
```

## Common problems

- **`exec format error` while building the other architecture.** No
  emulator is registered; run the `tonistiigi/binfmt` command above.
- **A gem fails to clone.** Builds need network access to GitHub on the
  first run. After that the gems in `build/*/repos/` are reused.
- **The lock file changed unexpectedly.** A new build target or a new gem
  adds entries to `build_config.rb.lock`. Check the diff and commit it.
- **Stale objects after changing `build_config.rb`.** Delete the target's
  directory under `build/` and build again.

## See also

- [Architecture](architecture.md) for how the code is organized and the
  rules for code that must run on mruby.
- [Install](../install.md) for the user side of the release files.
