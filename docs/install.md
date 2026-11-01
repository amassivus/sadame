# Install

Sadame is a single executable with no runtime dependencies: no Ruby, no
gems, no libraries. Each release has four builds. The Linux builds are
statically linked, so the same file runs on Debian, Ubuntu, Rocky, Alpine,
Arch and other distributions.

| System | CPU | File |
|---|---|---|
| Linux | x86_64 | `sadame-linux-amd64` |
| Linux | aarch64 (ARM64) | `sadame-linux-arm64` |
| macOS 11 or newer | Apple silicon | `sadame-darwin-arm64` |
| macOS 11 or newer | Intel | `sadame-darwin-amd64` |

Every release also has `SHA256SUMS`, the SHA-256 checksum of each file.

## Install script

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
```

The script (`install.sh` in the repository) picks the file for your system
and CPU, downloads it and `SHA256SUMS` from the latest release, stops if the
checksum does not match, and installs the binary as
`/usr/local/bin/sadame`, using `sudo` if that directory is not writable. It
needs `curl` or `wget`, and `sha256sum` or `shasum`.

| Variable | Default | Effect |
|---|---|---|
| `SADAME_VERSION` | latest release | Install this release, such as `v0.3.0`. |
| `SADAME_INSTALL_DIR` | `/usr/local/bin` | Install somewhere else, such as `$HOME/.local/bin`. |
| `SADAME_DOWNLOAD_URL` | the GitHub release | Download from a mirror that has the same files. |

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh \
  | SADAME_VERSION=v0.3.0 SADAME_INSTALL_DIR="$HOME/.local/bin" sh
```

Read the script before piping it to a shell if you prefer; it is about 100
lines of POSIX `sh`.

## Manual download

Download the binary for your system and `SHA256SUMS` from the
[releases page](https://github.com/enderkus/sadame/releases), then check
the binary before installing it.

On Linux:

```sh
version=v0.3.0
base=https://github.com/enderkus/sadame/releases/download/$version
curl -fsSLO "$base/sadame-linux-amd64"
curl -fsSLO "$base/SHA256SUMS"
sha256sum --ignore-missing -c SHA256SUMS
sudo install -m 0755 sadame-linux-amd64 /usr/local/bin/sadame
sadame --version
```

`sha256sum` prints `sadame-linux-amd64: OK` when the file is intact.

On macOS, use `shasum`:

```sh
shasum -a 256 --ignore-missing -c SHA256SUMS
```

The macOS binaries are not signed by Apple. Files downloaded with a web
browser are quarantined and refused on first run; files downloaded with
`curl`, as above and in the install script, are not. To run a binary you
downloaded with a browser, remove the quarantine flag:

```sh
xattr -d com.apple.quarantine sadame-darwin-arm64
```

## Homebrew

On macOS and Linux:

```sh
brew install enderkus/sadame/sadame
```

The formula, in the
[enderkus/homebrew-sadame](https://github.com/enderkus/homebrew-sadame)
tap, installs the release binary for your system after Homebrew checks its
SHA-256 checksum. It is updated for each release, so `brew upgrade sadame`
installs new versions.

## Arch Linux (AUR)

A `sadame-bin` package that installs the release binary is in
`packaging/aur/`, ready for the AUR but not submitted yet. Build and
install it from a checkout:

```sh
cd packaging/aur
makepkg -si
```

## From source

Run sadame from a checkout with Ruby 3.2 or newer, no build needed:

```sh
git clone https://github.com/enderkus/sadame.git
cd sadame
bin/sadame --version
```

Or build the binary yourself. `rake build:native` needs a C compiler,
`git`, `bison`, Ruby and `rake`; the static Linux builds need Docker:

```sh
rake build:native        # this machine, development build: build/host/bin/sadame
rake build:linux-amd64   # static Linux x86_64: dist/sadame-linux-amd64
rake build:linux-arm64   # static Linux ARM64: dist/sadame-linux-arm64
rake build:macos         # on a Mac: dist/sadame-darwin-arm64 and -amd64
```

[Building sadame](contributing/building.md) explains each target.

## Uninstall

```sh
sudo rm /usr/local/bin/sadame
```

Sadame keeps no other files on the machine it is installed on, except
`~/.sadame/dist/`, where it keeps binaries it downloaded for pushing to
other systems. On machines it was pushed to, it keeps `~/.sadame/` (see
[Remote hosts](guides/remote-hosts.md#what-is-copied-where)).

## Common mistakes

- **Picking the wrong CPU.** `uname -m` prints `x86_64` for
  `sadame-linux-amd64` and `aarch64` (Linux) or `arm64` (macOS) for the
  arm64 builds. The wrong one fails with "Exec format error".
- **Skipping the checksum.** A truncated download also fails to run, but a
  tampered one would not. `sha256sum -c` takes a second.
- **Installing into a directory not on `PATH`.** With
  `SADAME_INSTALL_DIR="$HOME/.local/bin"`, make sure that directory is in
  your `PATH`.

## See also

- [Getting started](getting-started.md)
- [Building sadame](contributing/building.md)
