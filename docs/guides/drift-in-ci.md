# Drift in CI

Servers drift: someone edits a file by hand during an incident, a package
upgrade rewrites a configuration, a service gets stopped and stays stopped.
This guide sets up a scheduled CI job that runs `sadame drift --json`
against every server in the inventory, fails the pipeline when one no longer
matches its recipe, and keeps the JSON report as an artifact, so the
failure tells you exactly what changed and where. Examples are given for
GitHub Actions and GitLab CI.

## How it works

The CI job installs sadame, loads an SSH key from the CI secrets, and runs:

```sh
sadame drift site/site.rb -g all --json > drift.json
```

Sadame connects to every host of the `all` group, copies itself there the
first time, compares each host with the recipe without changing anything,
and writes one JSON document with every host's report (see
[Remote hosts](remote-hosts.md)). Its exit status decides the job:

| Exit status | Meaning | Pipeline |
|---|---|---|
| `0` | every server matches the recipe | passes |
| `1` | at least one server differs from the recipe | fails |
| `2` | a server could not be checked: unreachable, a recipe error, or a state sadame could not read | fails |

On the console, the same run shows each host's differences prefixed with
its name, and a summary:

```text
--8<-- "docs/transcripts/remote-drift-limit.txt"
```

## Before you start

- The recipe and its `hosts.rb` in the repository, here in `site/`.
- A key pair for CI. Its public half goes in `authorized_keys` of the users
  named in `hosts.rb`; its private half is the `SSH_PRIVATE_KEY` secret.
- `SSH_KNOWN_HOSTS`: the output of `ssh-keyscan` for every server, so the
  job verifies host keys instead of trusting whatever answers.
- Passwordless sudo for those users, when the recipe needs root (most do;
  `drift` reads files only root can read).

The CI job installs sadame with `install.sh`, which downloads the latest
release. Until the first release (0.1.0) is published, there is nothing to
download; build sadame from source in the job instead (see
[Install](../install.md#from-source)).

## GitHub Actions

Copy this to `.github/workflows/drift.yml` and add the two secrets under
**Settings > Secrets and variables > Actions**:

```yaml title="examples/ci/github-actions-drift.yml"
--8<-- "examples/ci/github-actions-drift.yml"
```

`if: always()` on the upload step is what keeps the report when the drift
step fails, which is when you need it. The report appears under the run's
**Artifacts** as `drift-report`.

## GitLab CI

Add this job to `.gitlab-ci.yml`, add the two values as CI/CD variables,
and create a pipeline schedule under **Build > Pipeline schedules**:

```yaml title="examples/ci/gitlab-ci-drift.yml"
--8<-- "examples/ci/gitlab-ci-drift.yml"
```

`artifacts: when: always` keeps `drift.json` on failed jobs too.

## Reading the report

The report has one entry per host with its status and full report; the
format is in the [JSON output reference](../reference/json-output.md#push-mode).
This lists the resources that drifted, per host:

```sh
jq -r '.hosts[] | .name as $host | (.report.resources // [])[]
       | select(.status != "unchanged") | "\($host): \(.id) \(.status)"' drift.json
```

and this the hosts that could not be checked:

```sh
jq -r '.hosts[] | select(.status == "error" or .status == "unreachable") | "\(.name): \(.error)"' drift.json
```

Sadame's own CI runs `sadame drift --json` on its runner on every push,
edits a managed file, and expects exit status `1`; see
`.github/workflows/ci.yml` in the repository.

## Common mistakes

- **Unguarded `exec` resources.** They count as drift on every run, so the
  job never passes. Give each one a guard or `action: :nothing`.
- **No sudo.** Without it, files only root can read fail to compare and the
  job exits `2` instead of telling you about drift.
- **Losing the report on failure.** Without `if: always()` (GitHub) or
  `when: always` (GitLab), the upload step is skipped exactly when drift is
  found.
- **Trusting any host key.** `StrictHostKeyChecking=no` lets anyone who can
  answer for a server's name read your recipe and its vars. Pin the keys
  with `SSH_KNOWN_HOSTS`.
- **Applying from the drift job.** Keep the scheduled job read-only and
  review the drift first; apply on purpose, after looking at `plan`.

## See also

- [Remote hosts](remote-hosts.md): SSH, sudo and troubleshooting.
- [Plan, apply, drift](../concepts/plan-apply-drift.md): the three commands.
- [JSON output](../reference/json-output.md): the report format.
