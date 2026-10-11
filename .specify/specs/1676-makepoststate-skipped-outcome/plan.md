# Plan: 1676-makepoststate-skipped-outcome

- **Spec ID**: 1676-makepoststate-skipped-outcome
- **Created**: 2026-09-17

## Technical Context

- **Subject**: the `recordMakePostState` block in
  `lib/src/plugins/tdd/commands/run_driver_core.dart` (the per-step
  post-processing in the step loop) plus the verdict wording in
  `_recordMakePostState()` (same file). This is the only write side of
  `tdd/make-post-state.json`.
- **The record**: `MakePostState`
  (`lib/src/plugins/tdd/services/make_post_state.dart`, issue #1652) —
  the driving run's best-effort snapshot of the tree state a make just
  certified (`captured_at`, `behavior_id`, `suite`, `baseline_key`,
  `config_key`, `exempt_behaviors`, `lib_digest`, `test_digest`,
  `green_verdict`).
- **The consumer**: `refactor_command.dart` (issue #1652 rung) — a
  `--pass-batch` refactor spawn whose suite/baseline/config/exempt
  context and `lib/`+`test/` digests match the record inherits the
  pipeline (preflight, pass registry, re-proof skipped; the full gate
  still runs at phase-2b / feature completion / nightly). The consumer
  matches on digests and context keys, never on the verdict text — it is
  already verdict-agnostic, so no consumer change is needed.
- **Why `skipped` qualifies**: make's #694 skip transition re-runs the
  target test on the CURRENT tree before generation (FR-003 drift check;
  #1162 subject drift accepted; #1323 hand-delta re-certification) and on
  a pass certifies it green, appending green evidence and re-binding the
  hand-delta receipts (spec 1423). The `skipped` token therefore carries
  live post-state evidence on exactly the tree the record would describe.
  The exit-disagreeing token (bug #986 terminal classification,
  `skip-fail` shape) carries the same certification.
- **Language/SDK**: Dart 3.13+ pure-Dart package. Tests: `package:test`
  via the `TddFixture` fake-zfa harness (scripted step outcomes as real
  sub-processes) — `skip` → `outcome=skipped` exit 0; `skip-fail` →
  `outcome=skipped` exit 1.

## Architecture

```
 zfa tdd run  (recordMakePostState: true)
   step loop, after each step result
        │
        ├─ step == 'make' && outcome == 'green'   → _recordMakePostState (UNCHANGED, SC-5)
        ├─ step == 'make' && outcome == 'skipped' → _recordMakePostState (THE ONLY NEW BRANCH, SC-1/SC-2)
        │       verdict: 'make <id> outcome=skipped exit <n>
        │                (skip-transition target-test green evidence …)'
        └─ every other make token (adopted*, born-green, errors) → no record (UNCHANGED, SC-5)
        │
        ▼
 tdd/make-post-state.json
        │
        ▼
 refactor --pass-batch (issue #1652 rung, UNTOUCHED)
   record matches context + trees → inherit (SC-3)
   anything else → full pipeline; ledger keeps precedence (SC-4)
```

Single condition widened + verdict parameterized. Every other branch,
gate, and token is untouched.

## Phases

### Phase 1: red tests (test-first)

- Revise `U5b` in
  `test/plugins/tdd/run_driver_1652_make_post_state_test.dart`: the #694
  skip transition records its own certification (the old "writes nothing"
  contract is exactly what #1676 overturns) — record exists, names the
  skipping behavior, digests match the on-disk trees, verdict contains
  `outcome=skipped`.
- Add the `skip-fail` gate variant (SC-2): the exit-disagreeing token
  records too.
- Add the inheritance variant in
  `test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart`
  (SC-3): a skip-written record (verdict `outcome=skipped`) on the
  current tree inherits — zero suite spawns, honest evidence printed.
- Run → record RED evidence (`tdd/red-1676.log`): U5b-revised and the
  skip-fail variant fail pre-fix (no record written on skipped); the
  command-level variant passes pre-fix (characterization guard — the
  consumer side was already verdict-agnostic).

### Phase 2: green (single-point fix)

- Widen the recording condition:
  `result.outcome == 'green' || result.outcome == 'skipped'`.
- Pass the outcome into `_recordMakePostState` and build the verdict:
  `green` keeps the byte-identical
  `make <id> outcome=green exit <n> (post-generation green evidence)`;
  `skipped` honestly names the skip-transition target-test evidence.
- Update the block comment (the "deliberately writes nothing" rationale
  is what #1676 overturns) and the `MakePostState` library doc.
- No other file in `lib/` changes.

### Phase 3: verification (non-behavioural)

- `dart analyze` on the changed files: no new issues vs the repo
  baseline.
- Targeted `dart test` on the touched test files: driver-level #1652
  suite, command-level #1652 suite, defer-phase-1 suite (A1b/A1c pin the
  skip scheduling — must stay green).
- `dart format .`: zero formatting diffs in this branch's changes.
- Full-suite gates: asserted unchanged by construction (no gate code
  touched) and pinned by the existing suites (A2/U1a/U1b/U1c/U2/U2b/U3/
  U7/U8 all still run the full pipeline; U4 ledger precedence; U5c
  warning-not-error).
- Write `tdd/verification.md` FRESH from the actual run.

## Risks / notes

- The `skipped` token with a non-zero exit (`skip-fail`) records because
  the token is the terminal classification (bug #986) — the gate is the
  skip transition's own target-test certification, not the exit code.
  This matches the issue's gate wording ("gated on make having run and
  passed the target test, which the skip transition already does").
- `adopted`/`adopted-placeholder`/`adopted-interrupted` stay
  non-recording in this spec (SC-5 hard constraint: only the
  `MakePostState` recording condition changes; the adoption classes are
  re-drive flows, not the hand-step flow's terminal state).
- The record stays derived data describing ONE moment: a `skipped` make
  overwrites the standing record (the old one described the pre-hand-edit
  tree — stale by definition in the hand-step flow), and every existing
  staleness guard (digest mismatch → full pipeline) is unchanged.
