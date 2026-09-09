# Tasks — Spec 1354 simulate scenario subcommands honor the pinned feature

Dependency-ordered, MVP first. Every behavior task is written as a failing
test FIRST (tdd/test-list.md) before its implementation lands.

## Phase A — pinned-feature resolution (MVP, the issue's exact ask)

> MANDATORY: T001–T008 are behavior tasks (`[behavior: B#]`) — their tests
> are written and proven RED before any implementation lands.

- [x] T001. [behavior: B1] CLI: bare `zfa simulate init test_world` with a live
      `.specify/feature.json` pin scaffolds the world manifest under the
      PINNED feature (`specs/<pinned>/tdd/worlds/test_world.world.json` +
      certification receipt, exit 0) — byte-equivalent outcome to the
      explicit `--feature` twin. Traces FR-1, SC-001, AS-1.
- [x] T002. [behavior: B2] CLI: explicit `--feature B` beats a pin naming feature A —
      manifest lands under B only; A untouched. Traces FR-2, AS-2.
- [x] T003. [behavior: B3] CLI: no `--feature` + no `.specify/feature.json` → usage exit
      code, error names both missing inputs and the fix (no "positional
      ignored" wording), and nothing is written under `specs/`.
      Traces FR-4, SC-002, AS-3.
- [x] T004. [behavior: B4] CLI: pin pointing at a non-existent directory → usage exit
      code, error names the missing pinned path (honest refusal, never a
      specs/ scan). Traces FR-4, AS-4.

## Phase B — shared resolver parity

- [x] T005. [behavior: B5, B6, B7] CLI: bare `zfa simulate run test_world`, `certify
      test_world`, and `verify-world test_world` each resolve the pin and
      match their explicit-`--feature` twins (verdict, receipts, exit
      codes); parent-level `--feature` keeps working (B6); malformed pin
      degrades to no-pin honestly (B7). Traces FR-3, FR-4, FR-5, AS-5, AS-6.
- [x] T006. [behavior: B8] Help/usage text: subcommand `--feature` help documents the
      pinned-feature default (asserted via `simulate init --help` output).
      Traces FR-5.

## Phase C — implementation + hardening

- [x] T007. Implement the shared `_resolveFeature` pin fallback (explicit flag
      > `.specify/feature.json` `feature_directory` > honest usage error),
      the missing-pin-dir refusal, and the help-text updates (turns
      B1–B8 GREEN). Traces FR-1..FR-5.
- [x] T008. Regression pin: the pre-existing simulate suites stay green —
      run ONLY `test/simulation/worlds/simulate_worlds_command_test.dart`,
      `test/simulation/simulate_command_test.dart`,
      `test/commands/simulate_skin_command_test.dart`, plus the worlds
      unit tests under `test/simulation/worlds/` (disk ceiling; never the
      full suite). Traces FR-5, SC-003.
- [x] T009. `dart analyze lib/src/commands/simulate_command.dart` clean;
      `dart format` leaves zero diffs on touched files.

## Dependencies

- T001–T004 (Phase A) are the MVP; T005–T006 complete the behavior list.
- T007 is the single implementation task the loop's green step lands
  after the certified red.
- T008–T009 are hardening after the behavior tasks are green.
