# Cycle Log: tdd-120-template-structures

Append only. Newest last. Every entry's `red` block is the evidence that the test
existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 714 passed, 1 skipped, 0 failed (green)
- commit: `79169b56`
- recorded: cycle 0, before any change

## Cycle 1 — RED proof (T002, T004, T006, T008, T010, T012, T014, T016, T018)

- suite: `dart test test/plugins/tdd/bug_919_template_structures_test.dart`
- result: **+4 -10** (4 pass, 10 RED, 0 errors)
- commit: `79169b56`
- added: `test/plugins/tdd/helpers/spec_fixture.dart` (shared `writeSpec` /
  `writeRawSpec` / `makeFeatureDir` + `kMinimalAcceptance` constant).
- expanded: `test/plugins/tdd/bug_919_template_structures_test.dart` from 1 to
  14 behaviors covering A1-A14 (one test per behavior, all driving the real
  `CliRunner.runCapturing(['tdd', 'plan', ...])` on a temp project, same
  harness as `bug_846_coverage_gate_test.dart`).
- RED map (PENDING -> RED):
  - A1 table Key Entities -> `## Key entities` section missing
  - A3 read-back from table -> `## Key entities` section missing (no
    phase-0 path output to read)
  - A4 missing version -> no exit 3, plan proceeds to coverage gate
  - A5 unknown version -> no exit 3, plan proceeds
  - A6 already green (control)
  - A7 Dependencies table -> no `## External dependencies` rendered
  - A8 Layer Contracts -> no `## Layer contracts` rendered
  - A9 undeclared-dependency lint -> no exit 2 (Hive reference uncaught)
  - A10 already green (no-entities case)
  - A11 mixed table + bullet -> bullets ignored after the table
  - A12 already green (no-externals case)
  - A13 missing-version + coverage-gap -> currently throws "no acceptance
    scenarios" (StateError, exit 0) — the gate ordering proof will pass
    when the version gate moves ahead of the parser
  - A14 read-back -> no sections rendered
- next: implement SpecParser table parsing + Template Version gate +
  Dependencies/Layer Contracts extraction + dependency lint, then the
  artifact writer and TestListReader read-back methods, one cycle at a
  time.
