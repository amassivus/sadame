# Migrate from Ansible

Most Ansible playbooks for a single server map onto sadame resource by
resource: packages, files, templates, services, users and guarded commands
work the same way, with Ruby instead of YAML and ERB instead of Jinja2.
This guide translates the ten modules that make up most playbooks, then
the inventory, using `examples/migrate-from-ansible`: an Ansible playbook
and its translation, which the test suite applies on Debian and Ubuntu.

## What is the same, and what is not

| Ansible | sadame |
|---|---|
| playbook (YAML) | recipe (Ruby) |
| `hosts: web`, `--limit` | `-g web`, `--limit` |
| `vars:`, `group_vars`, `host_vars`, `-e` | `vars.rb`, group and host `vars` in `hosts.rb`, `--var` |
| Jinja2 templates | ERB templates with `vars` and `locals` |
| `notify:` and handlers | `notifies:` and `subscribes:` |
| `when:` | Ruby `if` |
| `ansible_facts`: `ansible_processor_vcpus`, `ansible_memtotal_mb`, `ansible_default_ipv4.address` | `facts[:cpus]`, `facts[:memory_mb]`, `facts[:ipv4]`; read when used, no `gather_facts` |
| `loop:` | Ruby `each` |
| `--check --diff` | `sadame plan` |
| `--syntax-check` | `sadame validate`, which also renders templates for each host |
| `tags:`, `--tags`, `--skip-tags` | `tags:` and `include_recipe ..., tags:`, `--tags`, `--skip-tags` |
| `forks` | `--forks` |
| `serial:` | `--serial` |
| no built-in drift command | `sadame drift` |
| `become: true` | `sudo: true` in `hosts.rb`, or `--sudo` |
| Python on every target | nothing on the targets; sadame copies itself |
| roles, collections, Galaxy | `include_recipe` and plain Ruby; no package manager for recipes |

Tasks run in order in both. A sadame resource reads the current state
before acting, as an idempotent Ansible module does; there is no
`changed_when`, because a resource changes exactly when its state
differs.

## The ten common modules

Each block shows the Ansible task and its translation from the example.

### package / apt / dnf

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:package"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:package"
```

`package` picks apt, dnf, apk or pacman from the distribution, so one
recipe covers several families.

### copy

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:copy"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:copy"
```

### template

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:template"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:template"
```

`{{ server_name }}` becomes `<%= vars[:server_name] %>`; `{% for %}` and
`{% if %}` become `<% ... %>` with Ruby. See
[Recipe basics](../recipes/basics.md#templates).

### file

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:file"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:file"
```

### service / systemd

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:service"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:service"
```

Handlers become the `service`'s notification actions: the handler

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:handlers"
```

is `notifies: [:reload, "service[nginx]"]` on the file that notified it.

### user

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:user"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:user"
```

### command / shell with creates

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:command"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:command"
```

`creates:` is the same; `removes:` has no equivalent, use `only_if: "test
-e PATH"`. A command without a guard runs on every apply in both tools,
and sadame's `drift` always reports it.

### lineinfile

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:lineinfile"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:lineinfile"
```

`line` is sadame's `lineinfile`: `match` plays the part of `regexp`, and
`state: :absent` removes the line. One difference: when several lines
match, `line` replaces all of them, where `lineinfile` replaces the last
one. Prefer managing the whole file with `file` when sadame can own it, so
the recipe states what the file contains; see [line](../resources/line.md).

### cron

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:cron"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:cron"
```

Ansible's `cron` edits the user's crontab by default; the translation uses
a file in `/etc/cron.d`, which names the user on each line. See
`examples/09-cron-and-logrotate`.

### get_url

```yaml
--8<-- "examples/migrate-from-ansible/ansible/playbook.yml:get_url"
```

```ruby
--8<-- "examples/migrate-from-ansible/recipe.rb:get_url"
```

## The inventory

An INI inventory:

```ini title="examples/migrate-from-ansible/ansible/inventory.ini"
--8<-- "examples/migrate-from-ansible/ansible/inventory.ini"
```

or its YAML form:

```yaml title="examples/migrate-from-ansible/ansible/inventory.yml"
--8<-- "examples/migrate-from-ansible/ansible/inventory.yml"
```

becomes:

```ruby title="examples/migrate-from-ansible/hosts.rb"
--8<-- "examples/migrate-from-ansible/hosts.rb"
```

| Ansible | `hosts.rb` |
|---|---|
| `[web]` with host lines | `group :web do host "..." end` |
| `ansible_host` | `address:` |
| `ansible_user`, `ansible_port` | `user:`, `port:` |
| `ansible_become=true` | `sudo: true` |
| `ansible_ssh_common_args` | `ssh_opts:` |
| `[web:vars]` | `vars` inside the group |
| `[all:vars]` | a group `:all` that includes the others; Ansible's `all` is implicit, sadame's is not |
| `[app:children]` | `group :app, include: [...]` |
| dynamic inventory scripts and plugins | Ruby in `hosts.rb`; see [Inventory](../recipes/inventory.md#dynamic-inventories) |

Precedence is similar: a host's vars override its groups', and a group's
vars override the groups it includes. Ansible has many more layers
(role defaults, facts, `set_fact`); sadame has four, listed on the
[Inventory](../recipes/inventory.md#vars-precedence) page.

## Gaps

Things Ansible does that sadame does not:

- sixteen facts (CPUs, memory, disk, addresses, virtualization) rather
  than Ansible's hundreds: no package, service or mount facts, no
  `facts.d`;
- ten resource types (`package`, `file`, `line`, `directory`, `link`,
  `service`, `exec`, `user`, `group`, `git`) where Ansible has thousands
  of modules: no `apt_repository`, `mount`, `sysctl`, `firewalld` and so
  on; use `file`, `line` and guarded `exec` (see `examples/04-docker-host`
  for a package repository);
- no `max_fail_percentage`: `--serial` stops after the first batch with a
  failure;
- no Windows, no network devices, no agent or pull mode;
- no vault; read secrets from the environment in `vars.rb`;
- no roles from Galaxy: recipes are files you `include_recipe`.

## Common mistakes

- **Translating `shell` tasks one to one.** Most `shell` tasks in a
  playbook exist because a module was missing; check whether a `file` or
  `package` resource says the same thing as state.
- **Forgetting the guard.** An `exec` without `creates`, `not_if` or
  `only_if` runs every time and makes `drift` fail.
- **Expecting `all` to exist.** Declare it in `hosts.rb` if you use it.

## See also

- [Inventory](../recipes/inventory.md)
- [Notifications](../recipes/notifications.md)
- [Comparison with other tools](../comparison.md)
