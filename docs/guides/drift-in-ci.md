# Drift in CI

Servers drift: someone edits a file by hand during an incident, a package
upgrade rewrites a configuration, a service gets stopped and stays stopped.
This guide sets up a scheduled CI job that runs `sadame drift --json` on a
server, fails the pipeline when the server no longer matches its recipe,
and keeps the JSON report as an artifact, so the failure tells you exactly
what changed. Examples are given for GitHub Actions and GitLab CI.

## How it works

`sadame drift` compares the machine with the recipe without changing
anything, and its exit status is the result:

| Exit status | Meaning | Pipeline |
|---|---|---|
| `0` | the server matches the recipe | passes |
| `1` | the server differs from the recipe | fails |
| `2` | sadame could not check: bad recipe, or a state it could not read | fails |

Sadame does not push itself to remote hosts yet, so the job copies the
recipe to the server with `scp` and runs sadame there with `ssh`. `ssh`
exits with the status of the remote command, so the CI step fails exactly
when `sadame drift` does. The JSON goes to standard output and is saved on
the CI runner:

```sh
ssh deploy@web1.example.com 'sudo sadame drift sadame-recipe --json' > drift.json
```

## Before you start

On the server:

- sadame installed (see [Getting started](../getting-started.md#install-from-source));
- a user the CI job can log in as, here `deploy`, allowed to run sadame
  with sudo without a password, for example with this line in
  `/etc/sudoers.d/sadame` (adjust the path to where sadame is installed):

  ```text
  deploy ALL=(root) NOPASSWD: /usr/local/bin/sadame
  ```

In the CI settings:

- `SSH_PRIVATE_KEY`: a private key whose public half is in
  `~deploy/.ssh/authorized_keys`;
- `SSH_KNOWN_HOSTS`: the output of `ssh-keyscan web1.example.com`, so the
  job verifies the server's host key instead of trusting whatever answers.

## GitHub Actions

Copy this to `.github/workflows/drift.yml` in the repository that holds
the recipe (here in `site/`), and add the two values above as repository
secrets:

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

The JSON lists every resource with its status and the changes found. For a
server where someone edited a configuration file and stopped nginx (the
[drift demo](../concepts/plan-apply-drift.md#the-loop-on-a-real-machine)),
this prints what drifted:

```sh
jq -r '.resources[] | select(.status != "unchanged") | "\(.id): \(.status)"' drift.json
```

```text
file[/etc/demo-app/app.conf]: update
service[nginx]: update
```

Each field is described in the [JSON output reference](../reference/json-output.md).

Sadame's own CI runs the same check on its runner on every push: it
applies `examples/01-hello`, saves `sadame drift --json`, edits the file and
expects exit status `1`. See `.github/workflows/ci.yml` in the repository.

## Common mistakes

- **Unguarded `exec` resources.** They count as drift on every run, so the
  job never passes. Give each one a guard or `action: :nothing`.
- **Running drift without sudo.** Files only root can read fail to compare,
  and the job exits `2` instead of telling you about drift.
- **Losing the report on failure.** Without `if: always()` (GitHub) or
  `when: always` (GitLab), the upload step is skipped exactly when drift is
  found.
- **Trusting any host key.** `StrictHostKeyChecking=no` lets anyone who
  can answer for the server's name read your recipe and its vars. Pin the
  key with `SSH_KNOWN_HOSTS`.
- **Applying from the drift job.** Keep the scheduled job read-only and
  review the drift first; apply on purpose, after looking at `plan`.

## See also

- [Plan, apply, drift](../concepts/plan-apply-drift.md)
- [JSON output](../reference/json-output.md)
