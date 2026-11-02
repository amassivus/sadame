---
hide:
  - toc
---

<div class="sadame-hero" markdown>

![Sadame](assets/logo-black.png#only-light){ width="160" }
![Sadame](assets/logo-white.png#only-dark){ width="160" }

# Sadame

**Sadame describes the desired state of Linux machines in plain Ruby,
shows every change as a diff before it happens, and applies it over SSH
from a single binary.**

[Get started](getting-started.md){ .md-button .md-button--primary }
[:octicons-mark-github-16: Star on GitHub](https://github.com/enderkus/sadame){ .md-button }

</div>

![A value changed in hosts.rb rolled out with plan and apply; after a hand edit on the server, drift reports it with exit status 1](assets/demo.gif)

??? quote "A run as text"

    `backup_hour` changed from 3 to 4 in `hosts.rb`; the `db` group gets
    the change, and `drift` confirms the server matches:

    ```text
    --8<-- "docs/transcripts/landing-plan.txt:1:1,4:9,11:11"

    --8<-- "docs/transcripts/landing-apply.txt:1:1,9:9,28:28"

    --8<-- "docs/transcripts/landing-drift.txt:1:1,4:4,9:9,11:12"
    ```

    The recipe and inventory are
    [`examples/08-multi-role-inventory`](./examples/index.md). The server
    runs no agent: on the first run, sadame copied itself there over SSH.

## Why sadame

<div class="grid cards sadame-columns" markdown>

-   :material-language-ruby:{ .lg .middle } **Plain Ruby**

    ---

    Recipes and the inventory are Ruby: loops, conditions and methods
    instead of YAML and templating rules. No Ruby to install; it is
    built in.

-   :material-file-compare:{ .lg .middle } **A diff before every change**

    ---

    `plan` shows what would change, line by line, and changes nothing.
    `apply` changes only what differs.

-   :material-ssh:{ .lg .middle } **No agent on the servers**

    ---

    SSH, a shell, `tar` and `sha256sum` are enough: sadame copies itself
    to each server for the run, and nothing keeps running afterwards.

-   :material-package-variant-closed:{ .lg .middle } **One small binary**

    ---

    About 1.5 MB, for Linux (x86_64, ARM64) and macOS. Nothing else to
    install, on your machine or on the servers.

-   :material-radar:{ .lg .middle } **Drift checks for CI**

    ---

    `drift` exits with status 1 when a machine no longer matches its
    recipe. Run it on a schedule and hear about hand edits.

-   :material-check-decagram:{ .lg .middle } **Tested on real systems**

    ---

    On every push, CI runs the examples in containers of Ubuntu, Debian,
    Rocky Linux, Alpine and Arch, on x86_64 and ARM64.

</div>

## Where to start

<div class="grid cards sadame-columns" markdown>

-   **New to configuration management**

    ---

    A free book, from a first recipe to a whole fleet, with a practice
    lab to follow along. Online, as a PDF and as an EPUB.

    [:octicons-book-24: The beginner's guide](https://enderkus.github.io/sadame-beginner-guide/)

-   **Users**

    ---

    Run sadame on servers and workstations: install it, apply a first
    recipe, check for drift.

    [:octicons-arrow-right-24: Getting started](getting-started.md)

-   **Recipe authors**

    ---

    Write recipes and inventories for a team: resources, vars,
    templates, notifications, `hosts.rb`.

    [:octicons-arrow-right-24: Recipe basics](recipes/basics.md)

-   **Contributors**

    ---

    Change sadame itself: architecture, the mruby build, the three test
    layers.

    [:octicons-arrow-right-24: Contributing](contributing/index.md)

</div>

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
```

The script downloads the binary for your system from the latest release,
checks its SHA-256 checksum and installs it to `/usr/local/bin`. Linux
(x86_64, ARM64) and macOS; Homebrew and other ways in [Install](install.md).

## How it compares

Recipes in Ruby like Itamae, push over SSH without an agent like Ansible,
one binary like mitamae, and a `drift` command for CI. Ten resource types
and Linux targets only, for now: the [comparison](comparison.md) lists
what the others do that sadame does not.

## Follow the project

Sadame is young, and a star on GitHub helps other people find it. News
and releases are posted on X as [@sadame_rb](https://x.com/sadame_rb);
bugs and ideas go to [GitHub issues](https://github.com/enderkus/sadame/issues).

[:octicons-star-16: Star on GitHub](https://github.com/enderkus/sadame){ .md-button .md-button--primary }
[:fontawesome-brands-x-twitter: Follow @sadame_rb](https://x.com/sadame_rb){ .md-button }
