---
hide:
  - navigation
---

<p align="center" markdown>
![Sadame](assets/logo-black.png#only-light){ width="180" }
![Sadame](assets/logo-white.png#only-dark){ width="180" }
</p>

# Sadame

Sadame (定め, "what is ordained") is a configuration management tool: you
describe the desired state of a machine in plain Ruby, `sadame plan` shows
the difference as a diff, and `sadame apply` makes the machine match.

```ruby title="examples/01-hello/recipe.rb"
--8<-- "examples/01-hello/recipe.rb"
```

```text
--8<-- "docs/transcripts/getting-started-plan.txt"
```

!!! note "Status"
    Sadame is under development towards 0.1.0. Today it runs recipes on the
    local machine with `plan`, `apply` and `drift`. Inventories, pushing to
    remote hosts over SSH, and release binaries are being built next.

## Where to start

<div class="grid cards" markdown>

- **Users** run sadame on servers and workstations.
  Start with [Getting started](getting-started.md).
- **Recipe authors** write recipes for their team.
  Start with [Recipe basics](recipes/basics.md), then the
  [resources](resources/package.md).
- **Contributors** change sadame itself.
  Start with [Contributing](contributing/index.md).

</div>
