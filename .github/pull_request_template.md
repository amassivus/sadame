## What and why

<!-- What this changes, and the problem it solves. Link the issue, if any. -->

## Checklist

- [ ] `bundle exec rake test` passes (CRuby and mruby).
- [ ] `mkdocs build --strict` passes.
- [ ] `CHANGELOG.md` has an entry under "Unreleased".

For a new feature or resource:

- [ ] A docs page or section in the standard shape: what and why, minimal
      example, option table, scenarios with real output, common mistakes,
      see also.
- [ ] An example under `examples/`, listed in `test/support/example_matrix.rb`
      and `test/unit/examples_test.rb`, embedded in the docs with `--8<--`.
- [ ] Terminal output in the docs captured with `rake docs:transcripts`,
      not typed.
