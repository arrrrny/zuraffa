# Bug Issue: zfa tdd run: deprecation warning on 6-column test-list is verbose and gives incorrect migration advice

- **Slug**: tdd-run-6col-deprecation-warning
- **Fetched**: 2026-09-01
- **Issue**: 649
- **URL**: https://github.com/arrrrny/zuraffa/issues/649
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Bug Description

When ❌ Error: Bad state: zfa tdd run: not yet implemented (Phase 10 of specs/041-tdd-setup-plugin/tasks.md, tasks T070-T076). encounters a  using the 6-column format (), it prints a deprecation warning:

**Problem 1**: The warning is verbose and alarming for users who have a valid 6-column list they did not create. Per spec 050, the 6-column dialect is accepted for one release — the loop should proceed transparently without a warning when the user did nothing wrong.

**Problem 2**: The migration advice is incorrect. The warning says "re-run `zfa tdd plan <feature>` to migrate" but `zfa tdd plan` writes `spec.md`, not `test-list.md`. The correct migration is a manual format conversion of the test-list itself.

## Steps to Reproduce

1. Have a feature at  using the 6-column format.
2. Run `zfa tdd run <feature>`
3. Observe the deprecation warning before the run proceeds.

## Expected Behavior

The loop proceeds transparently for valid 6-column lists (accepted per spec 050), or the warning text gives correct migration advice.

## Suspected Code Path

`lib/src/plugins/tdd/services/test_list_reader.dart:135-143` — the warning is printed unconditionally whenever 6-column rows are encountered. The rows are parsed correctly but the warning has incorrect migration text.

## Severity

medium — affects user experience for anyone using a 6-column test-list (including the zuraffa repo's own existing features).

## Comments

None.