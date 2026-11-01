# Exit codes

Every sadame command ends with an exit status a script can act on: `0`
when it did what was asked, `1` when `apply` failed or `drift` found a
difference, and `2` when sadame could not do its job at all: a wrong
command line, a broken recipe, a state it could not read, a host it could
not reach. `2` never means "the machine differs"; a CI job can tell "the
servers drifted" from "the check itself is broken".

## Minimal example

```sh
sadame drift site.rb -g all
case $? in
  0) echo "every host matches" ;;
  1) echo "drift: run apply, or update the recipe" ;;
  *) echo "the check could not run" ; exit 2 ;;
esac
```

## By command

| Status | `plan` | `apply` | `drift` | `hosts` |
|---|---|---|---|---|
| `0` | plan computed, with or without changes | every resource and notification succeeded | every host matches the recipe | hosts listed |
| `1` | not used | a resource or a notification failed | a host differs from the recipe | not used |
| `2` | usage or recipe error, a state could not be read, a host could not be reached | usage or recipe error, a host could not be reached | usage or recipe error, a state could not be read, a host could not be reached | usage or inventory error |

`plan` exits `0` even when there are changes: it answers "what would
change", not "is anything different". Use `drift` for that question.

## Several hosts

With remote targets, each host gets a result, and the run exits with the
highest status among them:

| Host result | Meaning | Status |
|---|---|---|
| `ok` | sadame finished on the host with status 0 | `0` |
| `drift` | `drift` found a difference on the host | `1` |
| `failed` | `apply` had a failed resource on the host | `1` |
| `error` | sadame could not run on the host, or exited with 2 there | `2` |
| `unreachable` | ssh could not connect | `2` |

One host that drifted makes the whole run exit `1`:

```text
--8<-- "docs/transcripts/remote-drift-limit.txt"
```

One host that cannot be reached makes it exit `2`, and the other hosts
still run:

```text
--8<-- "docs/transcripts/remote-unreachable.txt"
```

## Scenarios

**Fail a scheduled CI job only on drift.** Treat `1` and `2` differently,
so a broken check does not look like drift (and drift does not look like a
broken check). [Drift in CI](../guides/drift-in-ci.md) has complete
GitHub Actions and GitLab CI pipelines.

**Gate a deployment on a clean apply.** In a shell script, `set -e` stops
at the first failing host's exit status:

```sh
set -e
sadame apply site.rb -g db
sadame apply site.rb -g web
```

**Read the status per host.** `--json` reports each host's result and exit
status, for when one number for the whole run is not enough (see
[JSON output](json-output.md)).

## Common mistakes

- **Checking `plan`'s status for changes.** It is `0` either way; use
  `drift`.
- **Treating every non-zero status as drift.** `2` means the check did not
  complete; the servers may be fine.
- **Unguarded `exec` resources.** An `exec` without `creates:`, `not_if:`
  or `only_if:` always differs, so `drift` always exits `1`.

## See also

- [plan, apply, drift](../concepts/plan-apply-drift.md)
- [Command line](cli.md)
- [JSON output](json-output.md)
- [Drift in CI](../guides/drift-in-ci.md)
