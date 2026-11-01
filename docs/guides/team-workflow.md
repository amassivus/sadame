# Team workflow

When several people change the same servers, sadame works best with the
same habits as application code: recipes and the inventory in git, changes
through pull requests, the plan reviewed before anything is applied, and a
scheduled drift check that tells you when a server no longer matches the
repository. This guide sets that up with the pipelines in `examples/ci/`.

## The repository

Keep everything sadame reads in one repository:

```text
infrastructure/
  site/
    site.rb            # entry point; includes roles by host_groups
    hosts.rb           # the inventory
    vars.rb            # defaults
    roles/web.rb, roles/db.rb, roles/templates/...
  .github/workflows/
    plan.yml           # plan on every pull request
    apply.yml          # apply after merging, with approval
    drift.yml          # drift every morning
```

`examples/08-multi-role-inventory` has this shape. Secrets do not go in the
repository: read them from the environment in `vars.rb`
(`ENV["DB_PASSWORD"]`) and set them in the CI secrets; mark files that hold
them `sensitive: true` so their content does not appear in plans.

## Review the plan, not only the code

A recipe change is easier to review with its effect next to it. This
pipeline first checks the recipe for every host with `sadame validate`,
which connects to nothing and so also works for pull requests that cannot
read the SSH secrets, then runs `sadame plan` against every server and puts
the output on the run's summary page:

```yaml title="examples/ci/github-actions-plan.yml"
--8<-- "examples/ci/github-actions-plan.yml"
```

Reviewers then see, per host, the diff of every file the change touches,
packages to install, services to restart. A plan that shows more than the
author expected is the most useful thing a review can find. Like any
command it can only show what differs from the servers as they are now; if
someone changes a server by hand between the plan and the apply, the drift
check catches it.

## Who runs apply

Pick one and write it down:

| Model | How | Suits |
|---|---|---|
| Humans, after review | a maintainer runs `sadame apply site/site.rb -g ...` from their machine once the pull request is merged | small teams, few servers, changes that need watching |
| CI, after approval | the pipeline below, gated by a GitHub environment with required reviewers | teams that want a record of who applied what, and when |

```yaml title="examples/ci/github-actions-apply.yml"
--8<-- "examples/ci/github-actions-apply.yml"
```

`concurrency` makes sure two applies never run at once. In both models,
apply from the main branch only, so the servers match what is in git.

## Check for drift on a schedule

The third pipeline runs `sadame drift` every morning and fails when a
server differs from the recipe; [Drift in CI](drift-in-ci.md) explains it.
When it fails, either the server was changed by hand (apply to put it back,
after finding out why) or the change was intended (move it into the recipe
with a pull request).

## Conventions that help

- **Small pull requests.** One concern per change keeps the plan readable.
- **Run `sadame hosts` when changing the inventory.** It shows which
  hosts a selection reaches and where each var comes from.
- **Use `--limit` to roll out gradually.** Apply to `--limit "web1*"`
  first, then the rest.
- **Keep `exec` resources guarded.** An unguarded `exec` shows up in every
  plan and makes every drift check fail, which trains people to ignore
  both.

## Common mistakes

- **Applying from a branch.** The servers then match code nobody merged;
  the next apply from main undoes it.
- **Reviewing only the recipe diff.** A one-line change to a shared
  template can change files on every host; the plan shows it.
- **Ignoring drift failures.** A drift check that is always red gets
  muted; fix the cause or the recipe the same day.

## See also

- [Drift in CI](drift-in-ci.md)
- [Inventory](../recipes/inventory.md)
- [Remote hosts](remote-hosts.md)
