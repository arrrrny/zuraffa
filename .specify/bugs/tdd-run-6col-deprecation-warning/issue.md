# GitHub Issue

- URL: https://github.com/arrrrny/zuraffa/issues/649
- Number: 649
- Filed: 2026-08-31
- Title: zfa tdd run: deprecation warning on 6-column test-list is verbose and gives incorrect migration advice
- Severity: medium
- State (at fix time): open

> Record note: the triage records for this bug were expected to be committed
> under `.specify/bugs/tdd-run-6col-deprecation-warning/` but were absent from
> the repo at fix time (no branch contained them). This file is reconstructed
> verbatim from GitHub issue #649, and `assessment.md` from the assessment
> that accompanied the fix assignment. No re-triage was performed.

## Bug Description

When `zfa tdd run` encounters a feature using a test-list in the 6-column
format (`tdd/test-list.md`), it prints a deprecation warning:

```text
zfa: <feature>/tdd/test-list.md: deprecated 6-column test-list rows detected
(id/behavior/traces/kind/state/target). The canonical format is the 4-column
shape `zfa tdd plan <feature>` writes — re-run it to migrate; the 6-column
dialect is accepted for one release.
```

**Problem 1**: The warning is verbose and alarming for users who have a valid
6-column list they did not create. Per spec 050, the 6-column dialect is
accepted for one release — the loop should proceed transparently without a
warning when the user did nothing wrong.

**Problem 2**: The migration advice is incorrect. The warning says "re-run
`zfa tdd plan <feature>` to migrate" but `zfa tdd plan` writes `spec.md`, not
`test-list.md`. The correct migration is a manual format conversion of the
test-list itself.

## Steps to Reproduce

1. Have a feature at `specs/<feature>/` using the 6-column format.
2. Run `zfa tdd run <feature>`
3. Observe the deprecation warning before the run proceeds.

## Expected Behavior

- Valid 6-column lists (accepted per spec 050) must proceed transparently
  without a deprecation warning.
- Legacy rows must display accurate manual migration guidance.

## Suspected Code Path

`lib/src/plugins/tdd/services/test_list_reader.dart:135-143` — the warning is
printed unconditionally whenever 6-column rows are encountered. The rows are
parsed correctly but the warning has incorrect migration text.

## Severity

medium — affects user experience for anyone using a 6-column test-list
(including the zuraffa repo's own existing features).
