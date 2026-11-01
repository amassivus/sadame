---
hide:
  - navigation
  - toc
---

<p align="center" markdown>
![Sadame](assets/logo-black.png#only-light){ width="180" }
![Sadame](assets/logo-white.png#only-dark){ width="180" }
</p>

# Sadame

**Sadame describes the desired state of Linux machines in plain Ruby,
shows every change as a diff before it happens, and applies it over SSH
from a single binary.**

## See it work

`backup_hour` changed from 3 to 4 in `hosts.rb`; the `db` group gets the
change, and `drift` confirms the server matches:

```text
--8<-- "docs/transcripts/landing-plan.txt:1:1,4:9,11:11"

--8<-- "docs/transcripts/landing-apply.txt:1:1,9:9,28:28"

--8<-- "docs/transcripts/landing-drift.txt:1:1,4:4,9:9,11:12"
```

The recipe and inventory are
[`examples/08-multi-role-inventory`](./examples/index.md). The server runs
no agent: on the first run, sadame copied itself there over SSH.

## Where to start

<div class="grid cards" markdown>

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
(x86_64, ARM64) and macOS; other ways in [Install](install.md).

## How it compares

Recipes in Ruby like Itamae, push over SSH without an agent like Ansible,
one binary like mitamae, and a `drift` command for CI. Six resource types
and Linux targets only, for now: the [comparison](comparison.md) lists
what the others do that sadame does not.
