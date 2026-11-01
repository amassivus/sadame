# facts

What a recipe can know about the machine it runs on: CPUs, memory, disk,
addresses, virtualization. The recipe writes a login banner from facts,
sizes an application's configuration to the machine, gives a nightly job
a minute of its own, and leaves kernel settings out of containers.

Used by the [Facts](../../docs/recipes/facts.md) page. Runs everywhere, as
root.

| File | Purpose |
|---|---|
| `recipe.rb` | facts in Ruby code |
| `templates/motd.erb` | facts in a template |

```sh
sadame facts                       # what this machine's facts are
sudo sadame plan examples/facts
sadame facts -g all                # the facts of every host in hosts.rb
```
