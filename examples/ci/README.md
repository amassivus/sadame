# CI drift checks

Pipeline definitions that install sadame, run `sadame drift --json` against
every server in the inventory on a schedule, fail when one has drifted, and
keep the JSON report as an artifact. Explained on the
[Drift in CI](../../docs/guides/drift-in-ci.md) page.

**Who is this for:** teams that want to know when a server no longer
matches its recipe.

| File | For |
|---|---|
| `github-actions-drift.yml` | GitHub Actions; copy to `.github/workflows/drift.yml` |
| `gitlab-ci-drift.yml` | GitLab CI; add the `drift` job to `.gitlab-ci.yml` |

Both expect the recipe and its `hosts.rb` in a `site/` directory and reach
the servers over SSH with a key from the CI secrets.
