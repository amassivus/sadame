# 10-drift-demo

A recipe plus a script that deliberately breaks the machine, so you can
watch `sadame drift` catch it. Used on the
[Plan, apply, drift](../../docs/concepts/plan-apply-drift.md) page.

**Who is this for:** anyone deciding how to use `drift` in CI or on a
schedule.

Needs root, systemd, and Debian or Ubuntu (the nginx and `nologin` paths
are theirs). Try it in a throwaway VM or container.

```sh
sudo sadame apply examples/10-drift-demo
sudo sadame drift examples/10-drift-demo        # exit 0: no drift
sudo sh examples/10-drift-demo/break-things.sh
sudo sadame drift examples/10-drift-demo        # exit 1: two resources differ
sudo sadame apply examples/10-drift-demo        # puts everything back
```

| File | Purpose |
|---|---|
| `recipe.rb` | nginx, a system user, a config file and the service |
| `vars.rb` | values for the config template |
| `templates/app.conf.erb` | the config file template |
| `break-things.sh` | edits the config, changes its mode, stops nginx |
