# Bug Assessment: plan writes a 4-column test list that gen cannot parse

- **Slug**: plan-gen-test-list-column-mismatch
- **Created**: 2026-08-30
- **Source**: filed from spec 049-tdd-run research (Decision 5, task T025) —
  local reproduction
- **Verdict**: valid (reproduced locally, exit 1)
- **Severity**: high — breaks the plan → gen hand-off of the whole TDD loop

## Report (verbatim or summarized)

`zfa tdd plan` renders 4-column rows; `zfa tdd gen`'s `_parseBehaviorRow`
requires 6 cells and skips shorter rows, so `zfa tdd gen <id>` fails with
"unknown behavior id" for every freshly planned behavior.

## Symptom

See the linked issue.md (command transcript with exit code).

## Reproduction

Deterministic: seed `specs/<f>/tdd/test-list.md` with the exact output of
`plan_command.dart`'s `_render`, then run `zfa tdd gen <id>`. Reproduced
on branch 049-tdd-run @ 9986bfec (Dart 3.13.1, Linux x64):
`zfa tdd gen: unknown behavior id "U1"` → exit 1.

## Suspected Code Paths

- `plan_command.dart::_render` (writer, 4 columns).
- `gen_command.dart::_parseBehaviorRow` (reader, 6 columns).

## Root Cause Hypothesis

Two writers, one extension point: the 041-era gen parser was written
against a 6-column test-list sketch (`id|description|source|kind|state|
target`), while the 044-era plan command settled on the 4-column shape
the spec-kit extension's template also uses (`id|behavior|traces|state`).
Neither command owns the shared format, so they drifted.

## Proposed Remediation

Pick ONE canonical row format (recommendation: the 4-column shape plan
already writes, with kind inferred from the section header — it is also
what `test_list_reader.dart` now parses for `zfa tdd run`) and:

1. extend `gen_command._parseBehaviorRow` to accept it (derive kind from
   the enclosing section header, default target as it already does), and
2. pin both sides with a shared parser + round-trip contract test
   (`plan` writes → `gen` resolves → `run` reads the same rows).

Alternatively make gen accept both shapes during a transition window and
log a deprecation for the 6-column one.

## Risks & Considerations

- 6-column hand-written test lists exist in older specs; a hard switch
  would break them → the shared-parser contract test must cover both
  shapes if the transition keeps them.
- The spec-kit extension's `/speckit.tdd.plan` writes a 6-column table
  (`id|behavior|traces|kind|state|test`); whatever canonical format is
  chosen should be documented next to `test_list_reader.dart`.

## Open Questions

- Does anything still rely on the 6-column `target` cell (subject/test
  path hints), or can target derivation stay automatic?
