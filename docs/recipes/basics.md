# Recipe basics

A recipe is a [GNU Guile](https://www.gnu.org/software/guile/) Scheme file
that declares the desired state of a machine as a list of resources. Sadame
evaluates the file from top to bottom, collects the resources in the order
they appear, and then plans or applies them in that order. Because the
recipe is ordinary Scheme, loops, conditionals and helper procedures need no
special syntax. This page covers how a recipe directory is laid out, where
`vars` come from, how `include-recipe` splits a recipe into files, how
templates work, and the small set of procedures a recipe can call.

Sadame is a single C++ binary with Guile embedded and its own Scheme
sources compiled in, so there is nothing besides the binary to install.

## A complete example

The example used on this page lives in `examples/basics`:

```text
examples/basics/
  recipe.scm                 # entry point
  vars.scm                   # default vars
  parts/motd.scm             # included recipe
  parts/templates/motd.tmpl  # template used by parts/motd.scm
```

```scheme title="examples/basics/recipe.scm"
--8<-- "examples/basics/recipe.scm"
```

```scheme title="examples/basics/vars.scm"
--8<-- "examples/basics/vars.scm"
```

```scheme title="examples/basics/parts/motd.scm"
--8<-- "examples/basics/parts/motd.scm"
```

```text title="examples/basics/parts/templates/motd.tmpl"
--8<-- "examples/basics/parts/templates/motd.tmpl"
```

Planned on a fresh Debian 12 machine:

```text
--8<-- "docs/transcripts/basics-plan.txt"
```

## The recipe file

- Each resource is a procedure call: `(type "name" #:option value ...)`.
  The name identifies the resource: a package name, a path, a command, a
  user name. Together they form the resource id, `type[name]`, which shows
  up in output and is used by `#:notifies`.
- An id may appear only once. Declaring `(package "git")` twice is an error
  that names the file and line.
- Options are keyword arguments: `#:state 'absent`, `#:enable #t`,
  `#:groups '("docker")`. Dashes and underscores are interchangeable in
  option names, so `#:not-if` and `#:not_if` are the same option; this
  documentation writes dashes.
- Options are checked when the recipe loads. A misspelled option fails the
  whole run, with exit status 2, before anything is changed:

  ```text
  --8<-- "docs/transcripts/basics-unknown-option.txt"
  ```

- Scheme code in a recipe runs every time the recipe is loaded, for `plan`
  as well as `apply`. Use it to decide *what* to declare; make changes only
  through resources.

### Values

| Meaning | Scheme |
|---|---|
| a string | `"nginx"`, `"0644"` |
| true, false | `#t`, `#f` (and `#f` for "nothing"/unset) |
| a number | `1500` |
| a symbol (states, actions, tags) | `'absent`, `'running`, `'reload` |
| a list | `'("docker" "www-data")`; `(list a b)` when it holds variables |
| a name-to-value table | an association list: `'((A . "1") (B . "2"))` |
| a regular expression (`#:match` of `line`) | a string in ECMAScript syntax, backslashes doubled: `"^#?\\s*Port\\s"` |

A quoted list or alist does not evaluate its contents. When a value comes
from a variable, build it with quasiquote, `` `((port . ,port)) ``, or with
`(list (cons 'port port))`. In an association list the first entry for a
name wins, as with `assoc`, so `(append overrides defaults)` lets the
overrides win.

### What a recipe can call

Besides the resources, a recipe can use these procedures. Everything else
is Guile Scheme: `define`, `let`, `if`, `when`, `unless`, `for-each`,
`map`, `string-append`, `string-join` and the rest of the language; add
`(use-modules (srfi srfi-1))` and the like at the top of a file for more.

| Procedure | What it returns |
|---|---|
| `(vars 'name)` | the var `name`, or `#f` when it is not set; `(vars 'name default)` returns `default` instead; `(vars)` returns all vars as an association list (see below) |
| `(platform 'family)` | `"debian"`, `"rhel"`, `"alpine"`, `"arch"` or `#f` |
| `(platform 'package-manager)` | `"apt"`, `"dnf"`, `"apk"`, `"pacman"` or `#f` |
| `(platform 'id)`, `'version`, `'codename`, `'name`, `'description` | `ID`, `VERSION_ID`, `VERSION_CODENAME` and `PRETTY_NAME` from `/etc/os-release` (`'name` and `'description` are both `PRETTY_NAME`) |
| `(platform 'kernel)` | the kernel's name, `"Linux"`; the kernel release is `(facts 'kernel)` |
| `(facts 'cpus)`, `(facts 'memory-mb)`, `(facts 'ipv4)` and more | what the machine has, read from it; see [Facts](facts.md) |
| `(host-name)`, `(host-groups)` | the host's name, and its groups as a list of symbols, from the inventory; see [Inventory](inventory.md#using-groups-in-recipes) |
| `(include-recipe "path")` | evaluates another recipe file; `#:tags` tags everything it declares (see [Tags](tags.md)) |
| `(source-directory)` | the directory of the file being evaluated |
| `(read-text-file path)` | the contents of a file, as a string |
| `(json-parse text)` | JSON as Scheme data: objects become association lists with **string** keys, arrays become lists |

`(vars)`, `(platform)` and `(facts)` without an argument return everything
as an association list. Names are given as symbols; `'memory-mb` and
`'memory_mb` are the same name, in `vars`, `platform` and `facts` alike.

`(command-output "command")`, which runs a command and returns what it
printed, exists only in [`hosts.scm`](inventory.md#the-hostsscm-language).
A recipe that needs a command's result declares an `exec` instead, so that
`plan` stays free of side effects.

Procedures such as `define`d helpers belong to the file that defines them:
an included recipe cannot see the definitions of the file that includes it.

For example, a package whose name differs between distributions:

```scheme title="examples/resources/package/by_family.scm"
--8<-- "examples/resources/package/by_family.scm"
```

## vars

`(vars 'name)` reads the run's variables. In this release they are filled
from two places, highest precedence first:

| Precedence | Source | Example |
|---|---|---|
| 1 (highest) | `--var key=value` on the command line, repeatable | `--var workers=8` |
| 2 | `vars.scm` next to the recipe | `'((workers . 4))` |

`vars.scm` is Scheme whose last expression is an association list; code
before it can compute values, for example read an environment variable with
`(getenv "HOME")`, and quasiquote puts the results into the list:
`` `((home . ,(getenv "HOME"))) ``. Keys may be symbols or strings; dashes
and underscores are the same, so `(site-name . "x")` is read with
`(vars 'site-name)` or `(vars 'site_name)`.

Values given with `--var` are strings, except:

| Given | Becomes |
|---|---|
| `true`, `false` | `#t`, `#f` |
| digits with an optional leading `-`, and no leading zero | an integer: `8`, `-2`, `0` |
| anything else | a string: `"0644"`, `"1.5"`, `"web01"` |

Adding a maintenance window for one run changes the template output:

```text
--8<-- "docs/transcripts/basics-plan-maintenance.txt"
```

## include-recipe

`(include-recipe "parts/motd")` evaluates `parts/motd.scm`. The path is
relative to the file that contains the call, and `.scm` is optional. The
included file shares `vars` and adds its resources at that point in the
order. A file included more than once is evaluated only the first time, so
two roles can both include a common base recipe. Each file has its own
definitions: a `define` in one file is not visible in the others.

Templates and source files used by an included recipe are looked up relative
to *that* file, not the entry point. That keeps a directory such as `parts/`
or `roles/web/` self-contained.

## Templates

`file` with `#:template` renders a template: text with Scheme expressions
in it. Template files end in `.tmpl`. Four tags are all there is:

| Tag | Effect |
|---|---|
| `~{expr}` | inserts the value of the Scheme expression `expr`: strings, numbers and symbols as text, `#t` as `true`; `#f` and a missing value as nothing |
| `~(if expr)` ... `~(else)` ... `~(end)` | the text up to `~(else)` or `~(end)` appears only when `expr` is true; `~(else)` is optional |
| `~(each name list-expr)` ... `~(end)` | repeats the text once for each item of the list, with `name` bound to the item |
| `~;` | a comment: dropped, together with the rest of its line |
| `~~` | a literal `~`; needed only where the `~` would be followed by `{`, `(` or `;`, other `~` are ordinary text |

A line that holds only `~(if)`, `~(else)`, `~(each)`, `~(end)` or `~;` (and
blanks) is removed with its newline, so control tags leave no blank lines
behind.

For example, a template and what it renders with `vars` of
`'((port . 8080) (upstreams . ("a" "b")) (maintenance . #f))`:

```text
listen ~{(vars 'port)};
~(each u (vars 'upstreams))
server ~{u}:9000;
~(end)
~(if (vars 'maintenance))
return 503;
~(else)
return 200;
~(end)
```

```text
listen 8080;
server a:9000;
server b:9000;
return 200;
```

Expressions can use all of Guile: `~{(* 2 (vars 'workers))}`,
`~{(string-join (vars 'groups) ", ")}`,
`~{(or (facts 'virtualization) "no virtualization detected")}`. They see
these procedures and nothing else from the recipe:

| Procedure | What it returns |
|---|---|
| `(vars 'name)` | the run's [vars](#vars), as in a recipe |
| `(locals 'name)` | the value given in the `file` resource's `#:locals` |
| `(facts 'name)` | the machine's [facts](facts.md) |
| `(ref alist 'key)`, `(ref alist 'key default)` | the value for `key` in an association list, such as an item of a `~(each)` loop over a list of alists: `~{(ref job 'schedule)}` |

`#:locals` takes an association list; use quasiquote to put variables in
it: `` #:locals `((user . ,user)) ``.

The template is looked up in the recipe's directory first, then in its
`templates/` subdirectory. `parts/motd.scm` above uses `motd.tmpl`, found at
`parts/templates/motd.tmpl`.

After `apply`, changing a var shows exactly which lines of the rendered file
change:

```text
--8<-- "docs/transcripts/basics-plan-contact.txt"
```

An error in a template fails that resource and names the template and
line. Here `templates/app.conf.tmpl` contains `port = ~{port}`, and the
error reads `templates/app.conf.tmpl:1: Unbound variable: port`:

```text
--8<-- "docs/transcripts/basics-template-error.txt"
```

Here the template used `port` instead of `(locals 'port)`. The wording
after the line number comes from Guile.

## Common mistakes

- **Parentheses.** An unbalanced `(` fails the whole file; the error names
  the line where the form that is never closed starts. An editor that
  matches parentheses saves time.
- **A quoted list that should hold variables.** `'(a b)` is the symbols `a`
  and `b`, not the values of two variables. Use `(list a b)` or
  quasiquote.
- **Regular expressions as strings.** `#:match` takes a string, so
  backslashes are doubled: `"^#?\\s*PermitRootLogin\\s"`.
- **Printing `#f`.** `~{expr}` shows nothing for `#f`, not `false`. Compare
  or convert first if you want to print a boolean.
- **Expecting `--var port=08080` to be a number.** Leading zeros keep a
  value a string, so modes like `0644` survive.
- **Side effects in Scheme code.** Writing a file or running a command at
  the top of a recipe runs during `plan` too. Use `exec` with a guard
  instead.
- **Templates next to the wrong file.** A template used in `roles/web.scm`
  belongs in `roles/` or `roles/templates/`, not next to the entry recipe.

## See also

- [file](../resources/file.md) for `#:template`, `#:source` and `#:locals`.
- [exec](../resources/exec.md) for commands with guards.
- [Getting started](../getting-started.md) for reading plan output.
