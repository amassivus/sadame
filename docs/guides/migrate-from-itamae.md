# Migrate from Itamae

Sadame's recipe language comes from the same family as Itamae's and
mitamae's: Ruby files that declare resources, evaluated top to bottom, with
templates in ERB. Porting is mostly mechanical: resource names stay, block
attributes become keyword options, and `node` becomes `vars`. This guide
lists what is identical, what changed, and walks through
`examples/migrate-from-itamae`, an Itamae recipe and its translation, which
the test suite applies on Debian and Ubuntu.

## Side by side

=== "Itamae"

    ```ruby title="examples/migrate-from-itamae/itamae/recipe.rb"
    --8<-- "examples/migrate-from-itamae/itamae/recipe.rb"
    ```

=== "sadame"

    ```ruby title="examples/migrate-from-itamae/recipe.rb"
    --8<-- "examples/migrate-from-itamae/recipe.rb"
    ```

The template changes in one way: Itamae's `variables(...)` arrive as
instance variables, sadame's `locals:` as a Hash.

=== "Itamae"

    ```erb title="examples/migrate-from-itamae/itamae/templates/app.conf.erb"
    --8<-- "examples/migrate-from-itamae/itamae/templates/app.conf.erb"
    ```

=== "sadame"

    ```erb title="examples/migrate-from-itamae/templates/app.conf.erb"
    --8<-- "examples/migrate-from-itamae/templates/app.conf.erb"
    ```

## What is identical

- Recipes are Ruby files evaluated in order; resources run in the order
  they are declared.
- `package`, `directory`, `file`, `user` and `service` keep their names.
- `include_recipe "path"`, relative to the including file, each file once.
- `notifies` and `subscribes`, with delayed notifications by default and
  `:immediately`.
- `only_if` and `not_if` with shell commands, on `exec`.
- Templates are ERB with `<%= %>`, `<% %>` and `-%>`.

## What changed

| Itamae | sadame |
|---|---|
| `template "/path" do source "x.erb"; variables(a: 1) end` | `file "/path", template: "x.erb", locals: { a: 1 }` |
| `remote_file "/path" do source "files/x" end` | `file "/path", source: "x"` (looked up next to the recipe, then in `files/`) |
| `execute "name" do command "..." end` | `exec "name", command: "..."` |
| `service "x" do action [:enable, :start] end` | `service "x", enable: true, state: :running` |
| `action :nothing` | `action: :nothing`, on `exec` only; `service` without `enable:`/`state:` manages nothing |
| `node[:attr]`, `-j node.json`, `-y node.yml` | `vars[:attr]`, `vars.rb`, `--var`, vars in `hosts.rb` |
| `@name` in templates | `locals[:name]`; `vars[:name]` is also available |
| `notifies :reload, "service[x]"` | `notifies: [:reload, "service[x]"]` |
| `only_if` / `not_if` on any resource | on `exec` only |
| `define` | plain Ruby methods in the recipe |
| `run_command` in recipes | not available; recipes do not run commands while loading |
| `mode "644"` | `mode: "644"` or `"0644"`; numbers are rejected |
| `itamae local recipe.rb` | `sadame apply recipe.rb` |
| `itamae ssh -h host recipe.rb` | `sadame apply recipe.rb -h host` (copies itself; nothing to install on the host) |
| `--dry-run` | `sadame plan` |
| no drift command | `sadame drift` |

mitamae users: sadame is also a single binary built with mruby, so the
mruby limits on recipe code are similar (no gems, no standard library); see
[Architecture](../contributing/architecture.md#code-that-must-run-on-mruby).
The differences from mitamae are the same as above, plus push over SSH,
inventories and `drift`.

## Resources Itamae has and sadame 0.1 does not

`link`, `group`, `git`, `http_request`, `local_ruby_block`, `gem_package`
and plugins. Use `exec` with a guard in the meantime:

| Itamae | With sadame 0.1 |
|---|---|
| `link "/etc/app/current" do to "/srv/app/v2" end` | `exec "ln -sfn /srv/app/v2 /etc/app/current", not_if: "test \"$(readlink /etc/app/current)\" = /srv/app/v2"` |
| `group "deploy"` | `exec "groupadd deploy", not_if: "getent group deploy"` |
| `git "/srv/app" do repository "..." end` | `exec "git clone URL /srv/app", creates: "/srv/app/.git"` |

## How to port

1. Move `node.json` or `node.yml` values into `vars.rb` (a Ruby Hash).
2. Rewrite each resource block as a call with keyword options, using the
   table above. `sadame plan` rejects misspelled options with the list of
   valid ones.
3. Change `@name` in templates to `locals[:name]` or `vars[:name]`.
4. Move `only_if` and `not_if` from non-`exec` resources into Ruby `if`
   around the resource, or into an `exec`.
5. Run `sadame plan` on a machine Itamae already manages. A complete
   translation shows no changes, or only the differences you expect.

## Common mistakes

- **Expecting `@variables` in templates.** They are `nil` in sadame's
  templates; use `locals[:name]`.
- **`source` paths.** Itamae paths are relative to the recipe; so are
  sadame's, but sadame also looks in `templates/` and `files/`, so
  `"templates/x.erb"` and `"x.erb"` both work.
- **Guards on files and packages.** Only `exec` takes `only_if` and
  `not_if`; wrap other resources in Ruby `if`.

## See also

- [Recipe basics](../recipes/basics.md)
- [Notifications](../recipes/notifications.md)
- [Remote hosts](remote-hosts.md)
