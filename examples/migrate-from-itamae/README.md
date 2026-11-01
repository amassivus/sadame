# migrate-from-itamae

An Itamae recipe and the same configuration as a sadame recipe, used on
the [Migrate from Itamae](../../docs/guides/migrate-from-itamae.md) page.

**Who is this for:** Itamae and mitamae users trying sadame.

| File | Purpose |
|---|---|
| `itamae/recipe.rb`, `itamae/node.json`, `itamae/templates/`, `itamae/files/` | the original, for comparison |
| `recipe.rb` | the translation |
| `vars.rb` | `node.json` as vars |
| `templates/app.conf.erb` | the template, with `locals[:name]` instead of `@name` |

Runs on Debian and Ubuntu (it uses the `www-data` user).

```sh
sudo sadame apply examples/migrate-from-itamae
```
