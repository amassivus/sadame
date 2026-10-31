# basics

The recipe used on the [Recipe basics](../../docs/recipes/basics.md) page:
`vars.rb`, a loop over vars, `include_recipe`, and a template with a
conditional.

**Who is this for:** recipe authors learning the file layout.

```text
basics/
  recipe.rb                 # entry point
  vars.rb                   # default vars
  parts/motd.rb             # included recipe
  parts/templates/motd.erb  # template used by parts/motd.rb
```

Needs root and a Debian/Ubuntu, Rocky, Alpine or Arch host (it installs
packages and writes `/etc/motd`).

```sh
sudo sadame plan examples/basics
sudo sadame plan examples/basics --var maintenance="Sundays 02:00-03:00 UTC"
sudo sadame apply examples/basics
```
