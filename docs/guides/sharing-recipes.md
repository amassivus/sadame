# Sharing recipes

A recipe that more than one project needs, such as a hardened SSH
configuration or a team's nginx setup, can live in its own git repository
and be added to each project as a git submodule. Every project then pins
the version it uses, updates on purpose, and reviews the update like any
other change. Sadame needs nothing special for this: an included recipe is
a file in the project's directory, wherever it came from.

## Adding a shared recipe

```sh
git submodule add https://github.com/example/sadame-motd.git site/vendor/motd
git -C site/vendor/motd checkout v1.2.0       # the version this project uses
git add .gitmodules site/vendor/motd
git commit -m "Add the shared motd recipe at v1.2.0"
```

The submodule records the exact commit, so every clone, every CI run and
every push uses the same code until the project changes it.

Then include it from the project's recipe and give it the vars it reads:

```ruby title="examples/shared-recipes/site.rb"
--8<-- "examples/shared-recipes/site.rb"
```

```ruby title="examples/shared-recipes/vars.rb"
--8<-- "examples/shared-recipes/vars.rb"
```

The shared recipe's templates and files travel with it:
[`include_recipe`](../recipes/basics.md) looks for them next to the
included file. `tags:` on the `include_recipe` line tags everything the
shared recipe declares (see [Tags](../recipes/tags.md)).

## Writing a recipe to share

```ruby title="examples/shared-recipes/vendor/motd/recipe.rb"
--8<-- "examples/shared-recipes/vendor/motd/recipe.rb"
```

- **One entry point**, `recipe.rb` at the repository's root; split larger
  recipes into files it includes.
- **Defaults in the recipe**, with `vars.fetch(:name, default)`. A
  `vars.rb` in the shared repository is not read: only the project's is.
- **Prefixed var names**, such as `motd_contact`, so two shared recipes do
  not read each other's vars.
- **A README with a vars table**, as `vendor/motd/README.md` has, and tags
  for its versions.
- **No hosts.rb and no secrets.** The project decides where the recipe
  runs and what it is told.

## Updating

```sh
git -C site/vendor/motd fetch --tags
git -C site/vendor/motd checkout v1.3.0
git diff --submodule=diff site/vendor/motd    # what changed in the shared recipe
sadame plan site/site.rb -g all               # what it would change on the servers
git add site/vendor/motd
git commit -m "Update the shared motd recipe to v1.3.0"
```

Review the update in a pull request like any other change; the
[plan pipeline](team-workflow.md#review-the-plan-not-only-the-code) shows
its effect on every server.

## Cloning and CI

A clone needs the submodules too:

```sh
git clone --recurse-submodules https://github.com/example/infrastructure.git
git submodule update --init        # in a clone made without them
```

In GitHub Actions, check out with submodules:

```yaml
- uses: actions/checkout@v7
  with:
    submodules: true
```

In GitLab CI, set `GIT_SUBMODULE_STRATEGY: recursive` in the job's
`variables`. A shared recipe in a private repository needs credentials for
it in CI: a deploy key, or a token for HTTPS.

## What sadame does with it

- **Push mode** copies the project's directory, `vendor/` included, to each
  server, without any `.git`, so the submodule's history stays behind.
- **[validate](../reference/cli.md#validate)** and the
  [editor support](editors.md) check the shared recipe with the project's
  vars, like any other included file.
- **Nothing is downloaded on the servers.** The submodule is fetched once,
  on the machine that runs sadame.

## Common mistakes

- **A clone without the submodules.** `include_recipe` then fails with
  "cannot find vendor/motd/recipe.rb". Run `git submodule update --init`.
- **Changing the shared recipe inside `vendor/`.** The change belongs in
  the shared repository; make it there, tag it, and update the submodule.
- **Following a branch.** A submodule pins a commit; `git submodule update
  --remote` moves it to the branch's latest. Update to tags on purpose
  instead, and review what changed.
- **Trusting code you have not read.** A shared recipe runs as root on your
  servers. Read what an update changes before you apply it.

## See also

- [Recipe basics](../recipes/basics.md) for `include_recipe` and templates.
- [Team workflow](team-workflow.md) for reviewing changes.
