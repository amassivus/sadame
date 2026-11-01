# JSON output

`plan`, `apply` and `drift` print a single JSON document with `--json`,
instead of the human-readable report. It contains everything the text
report shows: each resource's status and changes, the notifications, the
summary counts, and the exit status. Nothing else is written to standard
output, so it can be redirected to a file or piped into `jq`. Errors that
stop sadame before a report exists (a bad option, a recipe that does not
load) go to standard error, and standard output stays empty.

## Example

`sadame drift --json` on the machine from
[Plan, apply, drift](../concepts/plan-apply-drift.md), after
`break-things.sh` ran:

```text
--8<-- "docs/transcripts/drift-demo-json.txt"
```

## Top level

| Field | Type | Description |
|---|---|---|
| `format_version` | integer | Version of this format, currently `1`. It changes when a field is removed or changes meaning; new fields may be added without a change. |
| `sadame_version` | string | Version of sadame that wrote the report. |
| `command` | string | `"plan"`, `"apply"` or `"drift"`. |
| `host` | string | The machine the report is about; `"local"` for the machine sadame runs on. |
| `platform` | object | See [platform](#platform). |
| `resources` | array | One [resource](#resource) object per declared resource, in recipe order. |
| `notifications` | array | [Notification runs](#notification-run) during `apply`, in the order they ran. Always empty for `plan` and `drift`. |
| `summary` | object | Number of resources per status; see [statuses](#statuses). Every status of the command is present, including those with `0`. |
| `drift` | boolean or null | `plan` and `drift`: `true` when at least one resource differs from the recipe. `apply`: `null`. |
| `failed` | boolean | `true` when a resource failed, or for `apply`, a notification failed. |
| `exit_status` | integer | The exit status of the command: see [Plan, apply, drift](../concepts/plan-apply-drift.md#when-to-use-which). |
| `duration_seconds` | number | Wall-clock time of the run, rounded to hundredths of a second. |

## platform

| Field | Type | Description |
|---|---|---|
| `name` | string | `PRETTY_NAME` from `/etc/os-release`, or `"macOS"`. |
| `family` | string or null | `"debian"`, `"rhel"`, `"alpine"`, `"arch"`, or `null` when unknown. |
| `package_manager` | string or null | `"apt"`, `"dnf"`, `"apk"`, `"pacman"`, or `null`. |

## resource

| Field | Type | Description |
|---|---|---|
| `id` | string | `type[name]`, as in the text output and in `notifies:`. |
| `type` | string | `"package"`, `"file"`, `"directory"`, `"service"`, `"exec"` or `"user"`. |
| `name` | string | The resource name: package name, path, command, user name. |
| `status` | string | See [statuses](#statuses). |
| `changes` | array | [Change](#change) objects. Empty when the resource is unchanged, failed before comparing, or skipped. |
| `notifications` | array | `plan` and `drift`: what this resource would trigger. `apply`: what it triggered. Each has `action`, `source`, `target` and `timing` (`"delayed"` or `"immediately"`). |
| `error` | string or null | Why the resource failed, or `null`. |

## change

An attribute that differs. Most changes have `from` and `to`:

| Field | Type | Description |
|---|---|---|
| `attribute` | string | `"state"`, `"mode"`, `"owner"`, `"group"`, `"enabled"`, `"uid"`, `"home"`, `"shell"`, `"groups"` or `"command"`. |
| `from` | string, integer, boolean, array or null | Current value; `null` when the resource does not exist yet. |
| `to` | same | Desired value. |
| `reason` | string | Only on `exec` changes: why the command would run, for example `"not_if exited non-zero"`. |

File content changes carry a diff instead of the full text:

| Field | Type | Description |
|---|---|---|
| `attribute` | string | `"content"` |
| `sensitive` | boolean | `true` when the file has `sensitive: true`. |
| `diff` | string or null | Unified diff from `current` to `desired`, or `null` when sensitive. |

## notification run

| Field | Type | Description |
|---|---|---|
| `action` | string | The action, such as `"reload"` or `"run"`. |
| `source` | string | Id of the resource whose change triggered it. |
| `target` | string | Id of the resource the action ran on. |
| `timing` | string | `"delayed"` or `"immediately"`. |
| `status` | string | `"ok"` or `"failed"`. |
| `error` | string or null | Why it failed, or `null`. |

## Statuses

| Command | Status | Meaning |
|---|---|---|
| `plan`, `drift` | `create` | Does not exist yet. |
| | `update` | Exists, some attributes differ. |
| | `remove` | Exists, the recipe says `state: :absent`. |
| | `run` | An `exec` whose guards say it must run. |
| | `unchanged` | Matches the recipe. |
| | `failed` | The current state could not be read; see `error`. |
| `apply` | `changed` | Was changed. |
| | `unchanged` | Already matched; nothing was done. |
| | `failed` | Changing it failed; see `error`. |
| | `skipped` | Not looked at, because an earlier resource or immediate notification failed. |

## Push mode

When sadame runs on remote hosts (`-h`, `-g`, `--limit`), `--json` prints
one document for the whole run. Each host's report, as described above, is
nested under `hosts`:

| Field | Type | Description |
|---|---|---|
| `format_version` | integer | As above. |
| `sadame_version` | string | Version of sadame on the machine that ran the push. |
| `command` | string | `"plan"`, `"apply"` or `"drift"`. |
| `hosts` | array | One object per host, in the order they were selected. |
| `hosts[].name` | string | The host's name from the inventory or `-h`. |
| `hosts[].status` | string | `"ok"`, `"drift"`, `"failed"`, `"error"`, `"unreachable"` or `"skipped"`; see [Remote hosts](../guides/remote-hosts.md#many-hosts-at-once). |
| `hosts[].exit_status` | integer or null | That host's exit status; `2` when it could not be reached or prepared; `null` when it was skipped. |
| `hosts[].error` | string or null | Why the host could not be reached or prepared, or sadame's error message. |
| `hosts[].report` | object or null | The host's report; `null` when sadame did not run there. |
| `exit_status` | integer | The highest exit status of all hosts: the run's exit status. |
| `duration_seconds` | number | Wall-clock time of the whole run. |

For example, a drift check on one web server after its configuration was
edited by hand:

```text
--8<-- "docs/transcripts/remote-drift-json.txt"
```

## Using it with jq

Resources that differ, from a saved drift report:

```sh
jq -r '.resources[] | select(.status != "unchanged") | "\(.id): \(.status)"' drift.json
```

```text
file[/etc/demo-app/app.conf]: update
service[nginx]: update
```

Only the counts:

```sh
jq '.summary' drift.json
```

```json
{
  "create": 0,
  "update": 2,
  "remove": 0,
  "run": 0,
  "unchanged": 3,
  "failed": 0
}
```

## Common mistakes

- **Reading `failed` as "drift found".** `failed` means a resource could
  not be checked or changed. Drift is the `drift` field, and the exit
  status `1`.
- **Parsing the text output.** Its layout is for people and may change;
  the JSON fields are documented here and versioned by `format_version`.
- **Mixing standard error into the file.** `> drift.json 2>&1` or
  `&> drift.json` puts error messages into the JSON file. Redirect only
  standard output: `> drift.json`.

## See also

- [Plan, apply, drift](../concepts/plan-apply-drift.md) for exit statuses.
- [Drift in CI](../guides/drift-in-ci.md) for keeping the report as a
  pipeline artifact.
