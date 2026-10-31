# CI drift checks

Pipeline definitions that run `sadame drift --json` against a server on a
schedule, fail when it has drifted, and keep the JSON report as an
artifact. Explained on the [Drift in CI](../../docs/guides/drift-in-ci.md)
page.

**Who is this for:** teams that want to know when a server no longer
matches its recipe.

| File | For |
|---|---|
| `github-actions-drift.yml` | GitHub Actions; copy to `.github/workflows/drift.yml` |
| `gitlab-ci-drift.yml` | GitLab CI; add the `drift` job to `.gitlab-ci.yml` |

Both copy the recipe directory (`site/` in the examples) to the server
with `scp` and run sadame there over `ssh`.
