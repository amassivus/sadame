# CI pipelines

Pipeline definitions that install sadame and run it against every server
in the inventory: a scheduled drift check that fails when a server has
drifted and keeps the JSON report as an artifact ([Drift in
CI](../../docs/guides/drift-in-ci.md)), and a plan on pull requests with an
approved apply after merging ([Team workflow](../../docs/guides/team-workflow.md)).

**Who is this for:** teams that want to know when a server no longer
matches its recipe.

| File | For |
|---|---|
| `github-actions-drift.yml` | GitHub Actions; copy to `.github/workflows/drift.yml` |
| `gitlab-ci-drift.yml` | GitLab CI; add the `drift` job to `.gitlab-ci.yml` |
| `github-actions-plan.yml` | GitHub Actions: `sadame plan` on every pull request ([Team workflow](../../docs/guides/team-workflow.md)) |
| `github-actions-apply.yml` | GitHub Actions: `sadame apply` after merging, once a reviewer approves ([Team workflow](../../docs/guides/team-workflow.md)) |

Both expect the recipe and its `hosts.rb` in a `site/` directory and reach
the servers over SSH with a key from the CI secrets.
