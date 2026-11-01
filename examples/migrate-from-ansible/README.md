# migrate-from-ansible

An Ansible playbook using the ten most common modules, and the same
configuration as a sadame recipe, used on the
[Migrate from Ansible](../../docs/guides/migrate-from-ansible.md) page. The
inventory is translated too.

**Who is this for:** Ansible users trying sadame.

| File | Purpose |
|---|---|
| `ansible/playbook.yml` | the original playbook, for comparison |
| `ansible/inventory.ini`, `ansible/inventory.yml` | the original inventory, in both formats |
| `recipe.rb` | the translation, section by section |
| `vars.rb`, `hosts.rb` | the playbook's vars and the inventory |
| `templates/app.conf.erb` | the Jinja2 template, in ERB |

Runs on Debian and Ubuntu (the playbook uses `apt`).

```sh
sudo sadame apply examples/migrate-from-ansible
```
