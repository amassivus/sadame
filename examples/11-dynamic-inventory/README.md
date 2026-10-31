# 11-dynamic-inventory

`hosts.rb` is Ruby, so a dynamic inventory is code that calls `host` in a
loop. Used on the [Inventory](../../docs/recipes/inventory.md) page.

**Who is this for:** anyone whose server list lives somewhere else: a
cloud provider, a CMDB, a file another tool writes.

| File | Builds the hosts from |
|---|---|
| `hosts.rb` | `servers.json`, next to it |
| `hosts-hcloud.rb` | `hcloud server list -o json` (Hetzner Cloud), grouped by the `role` label |
| `hosts-doctl.rb` | `doctl compute droplet list --output json` (DigitalOcean), grouped by tag |
| `hosts-aws.rb` | `aws ec2 describe-instances` (AWS), grouped by the `Role` tag |

The cloud files need the provider's CLI installed and logged in on the
machine running sadame. They run when the inventory loads, for every
command, including `sadame hosts`.

```sh
cd examples/11-dynamic-inventory
sadame hosts                                    # from servers.json
sadame hosts --inventory hosts-hcloud.rb        # from Hetzner Cloud
sadame plan recipe.rb -g web                    # run against the web group
```
