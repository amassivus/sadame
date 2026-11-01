# shared-recipes

A project that uses a recipe shared from another repository, the way the
[Sharing recipes](../../docs/guides/sharing-recipes.md) guide sets it up:
the shared recipe is a git submodule under `vendor/`, the project includes
it, and the project's `vars.rb` sets the vars it reads.

Runs everywhere, as root.

| File | Purpose |
|---|---|
| `site.rb` | includes the shared recipe, then the project's own resources |
| `vars.rb` | values for the shared recipe |
| `vendor/motd/` | the shared recipe, standing in for a submodule |

```sh
sudo sadame plan examples/shared-recipes/site.rb
sadame validate examples/shared-recipes/site.rb
```
