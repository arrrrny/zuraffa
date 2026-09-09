# Bug Assessment: plan writes FR text containing | into markdown table unescaped; run refuses its own test-list.md

- **Slug**: 1401-plan-pipe-escape-table-cells
- **Created**: 2026-09-09
- **Source**: https://github.com/arrrrny/zuraffa/issues/1401
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim record in issue.md)

`zfa tdd plan` succeeds on a spec whose FR/AC prose contains a literal
pipe (e.g. `todo filter <all|active|completed>`), interpolates the
description VERBATIM into a markdown pipe-table row, and writes
`tdd/test-list.md`. `zfa tdd run` then refuses that very file with
`expected 4 columns, found 6`. Plan and run disagree on the validity of
plan's own output — the worst failure mode: nothing fails at plan time,
and the loop's next leg is dead on arrival.

## Symptom (reproduced in this session, pre-fix)

Plan's own re-plan leg printed the refusal while reading the file the
first plan had just written:

```
zfa tdd plan: note: prior test list unreadable, ffi rows not preserved
(test-list.md line 26: expected 4 columns (id/behavior/traces/state),
found 6: "| U1 | The CLI MUST expose todo filter <all|active|completed>
selection on the command line. | FR-001 | PENDING |")
```

`dart test test/plugins/tdd/commands/plan_command_pipe_escape_1401_test.dart`
was RED before the fix: the writer-escape assertion failed and the
run-side reader (`TestListReader`) rejected the 6-cell row.

## Root Cause

`lib/src/plugins/tdd/commands/plan_command.dart` interpolated
`b.description` (plus traces, entity `purpose` and dependency
`contract` prose) into pipe-table rows without escaping, while every
consumer of the artifact splits cells on `|`:

- the run-side row reader `TestListReader._splitRow` splits on
  UNESCAPED pipes and already unescapes `\|` (spec 050, the U15 case) —
  correct, but it only helps when the WRITER escapes;
- plan's own meta-index reconcile reader used a naive
  `m.group(2)!.split('|')`, so even escaped input mis-split at re-plan.

Nothing in the spec-parser grammar forbids pipes in FR prose, so plan
happily emits a file run refuses. Writer and reader are consistent only
when no FR/AC text contains a pipe — an unstated, unenforced invariant.

## Constraints honored

- Fix confined to `plan_command.dart` (writer escape + reconcile-reader
  unescape) and tests. The core engine cycle, the run driver, the
  verify gate and the spec-parser grammar are untouched;
  `test_list_reader.dart` ended up unchanged (its `_splitRow` contract
  was already correct — the writer simply never met it).
- One PR per bug: `fix/1401-plan-pipe-escape-table-cells`.
