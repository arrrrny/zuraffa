# Bug Assessment: `zfa tdd plan` and `zfa tdd gen` speak different test-list dialects — the full loop is dead on arrival

- **Slug**: tdd-plan-gen-test-list-format-mismatch
- **Created**: 2026-08-31
- **Source**: pasted text (live reproduction, `/tmp/zfa-make-demo/run-c`)
- **Verdict**: valid
- **Severity**: critical

## Report (verbatim or summarized)

End-to-end run of the completed loop (all commands implemented and merged:
plan, gen, verify-red, make, refactor, run):

```
zfa tdd run: feature 001-demo — 2 behavior(s)
[run] A1 gen -> error
zfa tdd run: step failed — behavior=A1 step=gen outcome=error
   ❌ Error: Bad state: zfa tdd gen: unknown behavior id "A1"
run: feature=001-demo result=stopped pending=2 red=0 green=0 done=0 stopped_at=A1:gen
```

`zfa tdd run` stopped honestly (the driver itself worked correctly);
the failure is that `gen` cannot read the test list `plan` produces.

## Symptom

`zfa tdd plan` writes 4-column behavior rows
(`| id | behavior | traces | state |`), but `zfa tdd gen`'s parser skips any
row with fewer than 6 cells — so every behavior planned by `plan` is
"unknown" to `gen`, and `zfa tdd run` can never get past its first step.
The loop only works when the test list is hand-written in gen's 6-column
dialect, which `zfa tdd run`'s own reader then rejects (it requires exactly
4 columns).

## Reproduction

1. Minimal Dart project (deps as in #609/#610 demos) + quoted tdd-profile +
   `specs/001-demo/spec.md` containing one `Given/When/Then` scenario and
   one `FR-NNN` requirement.
2. `zfa tdd plan 001-demo --project .` → writes 4-column `tdd/test-list.md`
   (1 acceptance + 1 unit behavior).
3. `zfa tdd run 001-demo --project .` → `[run] A1 gen -> error` →
   `result=stopped stopped_at=A1:gen`.

Preserved at `/tmp/zfa-make-demo/run-c`.

## Suspected Code Paths

- `lib/src/commands/...` / `lib/src/plugins/tdd/commands/plan_command.dart`
  (writer) — emits 4-column rows (`id/behavior/traces/state`).
- `lib/src/plugins/tdd/commands/gen_command.dart:250-263` — private parser
  requires `parts.length >= 7` and `cells.length >= 6`
  (`| id | description | source | kind | state | target |`); rows with
  fewer cells are silently skipped, so 4-column rows never match.
- `lib/src/plugins/ttd/services/test_list_reader.dart:113` (run's shared
  reader) — requires exactly 4 columns; would reject gen's 6-column dialect.

## Root Cause Hypothesis

Two independently-grown parsers with no shared format contract: 041's plan
writer, 044's gen parser, and 049's TestListReader were never reconciled.
High confidence — both sides verified by direct code read plus a live
reproduction of the failure and of each dialect.

## Proposed Remediation

**Preferred**: make the test-list format a single contract. Have `gen`
consume the shared `TestListReader` (kind already derives from the section
header; move gen's target-defaulting logic — snake_case from behavior id —
into the reader or gen's adapter), and keep `plan`'s 4-column output as the
canonical shape. Add ONE slow-tier end-to-end test that is exactly the
run-c demo: `plan` → `run` on a real temp project with the real pipeline —
any format drift then fails CI at the loop's front door.

**Alternatives**:
- `plan` emits the 6-column gen dialect — rejected: breaks `run`'s reader
  and the speckit tdd-plan template contract.
- Accept both shapes in both parsers — rejected: two dialects is the bug,
  not the fix.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/gen_command.dart` (use shared reader)
- `lib/src/plugins/tdd/services/test_list_reader.dart` (target defaulting)
- `test/plugins/tdd/` (gen parsing tests + the new loop e2e slow test)

**Tests to add or update**:
- `plan`-written list → `gen <id>` resolves (currently impossible).
- Slow-tier loop e2e: plan → run → all DONE with real pipeline.

## Risks & Considerations

- Existing hand-written 6-column test lists (fixtures, older features)
  would stop resolving after the fix; provide a one-release compatibility
  shim or a documented migration (grep the repo for 6-column fixtures).

## Open Questions

- None blocking; the canonical format should be whatever `plan` writes
  (4-column), confirmed by the speckit tdd extension's own template.
