# Bug Issue: plan writes a 4-column test list that gen cannot parse

- **Slug**: plan-gen-test-list-column-mismatch
- **Created**: 2026-08-30
- **Source**: filed from spec 049-tdd-run research (Decision 5, task T025) —
  local reproduction, no GitHub issue yet
- **State**: open

## Symptom

`zfa tdd plan <feature>` writes behavior rows in a 4-column format:

```text
| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | does the thing | FR-1 | PENDING |
```

but `zfa tdd gen <behavior-id>` scans that same test list with a parser
that requires 6 cells (`id | description | source | kind | state |
target`) and silently SKIPS any row with fewer, so every behavior in a
freshly-planned feature is reported as unknown:

```text
$ zfa tdd gen U1 --feature 099-gap-repro --project <fixture>
zfa tdd gen: unknown behavior id "U1". No matching row found in any
specs/<feature>/tdd/test-list.md for feature 099-gap-repro.
❌ Error: Bad state: zfa tdd gen: unknown behavior id "U1"
$ echo $?
1
```

The full red-green-refactor loop (specs 041/044/046/049) is therefore
broken at its first hand-off: plan's output is gen's input, and gen
cannot read it.

## Reproduction

1. Create a fixture project with `specs/099-gap-repro/tdd/test-list.md`
   containing exactly the rows `plan_command.dart` renders
   (`_render` writes `| id | behavior | traces | state |`).
2. Run `dart run bin/zfa.dart tdd gen U1 --feature 099-gap-repro
   --project <fixture>`.
3. Observe the "unknown behavior id" failure above (exit 1).

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/plan_command.dart` — `_render` emits
  4-column rows.
- `lib/src/plugins/tdd/commands/gen_command.dart` — `_parseBehaviorRow`
  (`if (parts.length < 7) continue; // need 6 cells + 2 outer empties`)
  drops every row that is not 6-column.

## Impact

Blocks the epic 045 full-app TDD cycle (`zfa tdd run` can drive gen only
if gen can resolve planned behaviors). The 049 driver intentionally
parses the 4-column format (the writer's format is the contract) and
surfaces this gap instead of papering over it.

## Notes

Filed per specs/049-tdd-run/tasks.md T025 and the epic's gap protocol.
Owner: specs 044/041 command contracts (NOT fixed by 049 — out of
scope there).
