# 01-hello

The smallest possible recipe: a single `file` resource. It writes to `/tmp`,
so it runs without root on any Linux machine or Mac.

**Who is this for:** anyone trying sadame for the first time.

```sh
sadame plan examples/01-hello
sadame apply examples/01-hello
sadame plan examples/01-hello   # nothing left to change
```

Walkthrough: [Getting started](../../docs/getting-started.md).
