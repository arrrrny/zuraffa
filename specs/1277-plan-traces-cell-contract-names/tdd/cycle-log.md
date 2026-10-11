# Cycle Log: 1277-plan-traces-cell-contract-names

Append only. Newest last. Every entry's `red` block is the evidence that
the test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/commands/plan_routing_provenance_test.dart test/plugins/tdd/commands/plan_lanes_1000_test.dart test/plugins/tdd/commands/plan_gen_contract_test.dart test/plugins/tdd/commands/plan_persistence_marking_833_test.dart test/plugins/tdd/commands/plan_command_ffi_835_test.dart test/plugins/tdd/commands/plan_command_bug_1182_test.dart test/plugins/tdd/commands/plan_skin_contract_1004_test.dart test/plugins/tdd/commands/plan_marker_emission_1186_test.dart test/plugins/tdd/commands/corpus_run_plan_test.dart test/plugins/tdd/bug_1259_vacuous_green_test.dart test/plugins/tdd/bug_993_plan_entity_export_clash_test.dart test/plugins/tdd/services/routing_resolver_test.dart` -> 118 passed, 0 failed (post-fix fence; the same suites were green on the untouched tree at 37c38f2)
- commit: `37c38f2`
- recorded: cycle 0, before any change
- cloud-agent scope: only suites covering the modified file
  (`plan_command.dart`) plus the new #1310 suite — never the full suite.

## Cycle 1: U1 the legacy single-file plan unit cell carries the full trace set

- test: `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart::U1`
  (new)
- red: `dart test test/plugins/tdd/commands/plan_traces_cell_1310_test.dart --plain-name "U1"`
  ->
  `Actual: '| U1 | System MUST let the user add a todo with a title | FR-001 | PENDING |'`
  — `Which: does not contain 'FR-001, TodoRepository.create'` (1 failed).
  The plan's own provenance line in the same run read
  `route: U1 -> unit lane [declared: contract row: TodoRepository, spec line 8]`
  — plan RESOLVES the contract row and never writes it into the cell.
- green: `plan_command.dart` — added the `contractTraces` map
  (behavior.id -> `frTraces[currentId]`, paired via `expressibleEntries`
  so reconciled historical ids stay correct), the `_tracesCell` cell
  renderer (criterion id first, resolved contract names after,
  criterion-only when no names), and wired it into the three legacy
  writers (acceptance / widget / unit) AND the lane writer
  `_derivedLaneRows` (both call sites). Suite -> 1 passed.
- refactor: none needed — the helper is the single cell renderer both
  plan shapes share.
- commit: (this PR)

## Cycle 2: U2 the lane plan (04-ENGINE.md) unit cell carries the same full trace set

- test: `...::U2` (new)
- red: not recorded as a separate cycle — Cycle 1's green step wired
  `_derivedLaneRows` in the same edit (the lane writer routes through
  the same `_tracesCell` helper; splitting the cycles would have
  required staging a knowingly-incomplete fix). U2 runs as the
  verification of that wiring: green at write time
  (`| U1 | ... | FR-001, TodoRepository.create | PENDING |` in
  04-ENGINE.md).
- green: suite -> 2 passed
- refactor: none
- commit: (this PR)

## Cycle 3: U3 an FR with no traces continuation keeps the criterion-only cell

- test: `...::U3` (new, compat fence / characterization of the fallback
  path pinned by acceptance criterion 4)
- red: none — expected green BEFORE the fix by design (the fallback path
  must not change); green at write time.
- green: suite -> 3 passed
- refactor: none
- commit: (this PR)

## Cycle 4: U4 re-planning a list carrying full trace-set cells keeps the row id

- test: `...::U4` (new) — plan a two-FR traced spec, delete FR-001 from
  the spec, re-plan; the surviving FR-002 behavior must keep its prior
  U2 id.
- red: `dart test ... --plain-name "U4"` -> `Actual: <null>` — the
  re-plan renumbered the row: the list carried
  `| U1 | System MUST let the user complete a todo | FR-002, TodoRepository.create | PENDING |`
  and no U2 row. Root cause: the prior-list read regex
  `\|\s*([A|U]\d+)\s*\|.*?\|\s*([A-Z0-9\-, ]+)\s*\|` cannot span `.` and
  cannot survive the comma-greedy space, so the match degraded to the
  STATE cell (`PENDING`) — the reconciliation map got garbage keys and
  `existing[b.sourceCriterion]` missed (probed independently with a
  standalone regex probe before the fix).
- green: `plan_command.dart` — replaced the regex read with a positional
  parse (leading id cell, pipe-split the remaining cells, traces =
  second-to-last cell, state last; both the 4-column and 5-column
  dialects) and keyed the reconciliation map by the cell's LEADING
  criterion token. Suite -> 4 passed.
- refactor: none
- commit: (this PR)

## Cycle 5: U5 gen derives the declared signature for a planned traced behavior

- test: `...::U5` (new) — plan the repro spec in a TddFixture project,
  `tdd gen U1`, read the registry-recorded pair.
- red: not a separate cycle — this is the end-to-end verification of
  Cycle 1's fix (the declared path becoming reachable IS the issue's
  acceptance criterion 2; the enabling change was Cycle 1's). Green at
  write time: subject carries the provenance
  `create(String title) -> bool` and the declared signature
  `bool subject_u1(String title)`; the paired test asserts
  `expect(result, isA<bool>())` with no `vacuous-guard` marker.
- green: suite -> 6 passed (U5 + U7 added in the same batch)
- refactor: none
- commit: (this PR)

## Cycle 6: U6 make certifies green for the planned behavior

- test: `...::U6` (new) — plan -> gen -> `tdd verify-red` (honest red
  evidence) -> rewrite the subject body to `=> false;` -> `tdd make`.
- red: two test-defect iterations, neither a product regression:
  1. first run failed `make must certify` — make refused with
     `outcome=not-certified-red` because the flow skipped verify-red
     (process discipline, not the fix); added the verify-red step.
  2. second run failed in make's repair step — the subject rewrite used
     the wrong pattern (`throw UnimplementedError();` vs the emitted
     expression form `=> throw UnimplementedError('...: <declared
     signature>');`), so the baseline stayed red and make's func
     subprocess crashed on an environment isolate quirk (`type 'Null'
     is not a subtype of type 'SendPort'`); fixed the rewrite pattern in
     the TEST.
- green: after the test correction: verify-red certifies, make
  certifies green (exit 0, no `outcome=vacuous-green`) — the real
  outcome assertion keeps the run off the vacuous-green dead-end. Suite
  -> 7 passed.
- refactor: none
- commit: (this PR)

## Cycle 7: U7 re-planning a legacy criterion-only prior list still reconciles ids

- test: `...::U7` (new, compat fence) — the pre-#1310 cell shape through
  the NEW positional read: first comma-token of a criterion-only cell is
  the cell itself, so the key is identical. Green at write time.
- green: suite -> 7 passed
- refactor: none
- commit: (this PR)

## Regression fence (post-fix, same session)

- `dart test` on the 12 plan/routing/1259 suites listed at Baseline ->
  118 passed, 0 failed.

## Notes and deviations

- Cycle 2 (U2), Cycle 5 (U5) and Cycle 7 (U7) were verifications rather
  than red-first cycles: the enabling change for each was Cycle 1's /
  Cycle 4's, and U3/U7 are compat fences that must be green by design.
  Recorded here per the audit's honesty rule instead of staging
  artificial reds.
- Mutation sampling (verification Phase 4; no mutation tool wired per
  the stack profile):
  - Mutant M1 — `_tracesCell` returns the criterion id unconditionally
    (contract names dropped): suite -> 3 passed, 4 FAILED (U1, U2, U5,
    U6). KILLED.
  - Mutant M2 — reconciliation keys by the full cell instead of the
    leading criterion token: U4 -> 1 FAILED with the renumbering
    symptom (`| U1 | ... | FR-002, TodoRepository.create | PENDING |`).
    KILLED.
  - The working tree was restored byte-identical after each mutant
    (`diff` clean) and the suite re-run green.
- make's `tdd func` repair subprocess crashed in this sandbox with a
  Dart VM isolate error when invoked on a failing baseline; the
  certify-green path (the one the issue dead-ends on) does not exercise
  that subprocess.
