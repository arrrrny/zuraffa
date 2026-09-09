# Tasks — Spec 1354 simulate scenario subcommands honor the pinned feature

Dependency-ordered, MVP first. Every behavior task is written as a failing
test FIRST (tdd/test-list.md) before its implementation lands.

## Phase A — pinned-feature resolution (MVP, the issue's exact ask)

- [ ] T001. CLI: bare `zfa simulate init test_world` with a live
      `.specify/feature.json` pin scaffolds the world manifest under the
      PINNED feature (`specs/<pinned>/tdd/worlds/test_world.world.json` +
      certification receipt, exit 0) — byte-equivalent outcome to the
      explicit `--feature` twin. Traces FR-1, SC-001, AS-1.
- [ ] T002. CLI: explicit `--feature B` beats a pin naming feature A —
      manifest lands under B only; A untouched. Traces FR-2, AS-2.
- [ ] T003. CLI: no `--feature` + no `.specify/feature.json` → usage exit
      code, error names both missing inputs and the fix (no "positional
      ignored" wording), and nothing is written under `specs/`.
      Traces FR-4, SC-002, AS-3.
- [ ] T004. CLI: pin pointing at a non-existent directory → usage exit
      code, error names the missing pinned path (honest refusal, never a
      specs/ scan). Traces FR-4, AS-4.

## Phase B — shared resolver parity

- [ ] T005. CLI: bare `zfa simulate run test_world`, `certify
      test_world`, and `verify-world test_world` each resolve the pin and
      match their explicit-`--feature` twins (verdict, receipts, exit
      codes). Traces FR-3, AS-5.
- [ ] T006. CLI: parent-level `zfa simulate --feature <f> init <scenario>`
      still resolves `<f>` (regression guard — bug #856 dispatch and the
      parent-flag path unchanged). Traces FR-5, AS-6.

## Phase C — docs + hardening

- [ ] T007. Help/usage text: subcommand `--feature` help documents the
      pinned-feature default; parent invocation string and library docs
      mention the pin; the unresolvable error text names the resolution
      steps (covered by the T003/T004 assertions where observable via
      stdout). Traces FR-5.
- [ ] T008. Regression pin: the pre-existing simulate suites stay green —
      run ONLY `test/simulation/worlds/simulate_worlds_command_test.dart`,
      `test/simulation/simulate_command_test.dart`,
      `test/commands/simulate_skin_command_test.dart`, plus the worlds
      unit tests under `test/simulation/worlds/` (disk ceiling; never the
      full suite). Traces FR-5, SC-003.
- [ ] T009. `dart analyze lib/src/commands/simulate_command.dart` clean;
      `dart format` leaves zero diffs on touched files.

## Dependencies

- T001–T004 (Phase A) are the MVP; T005–T006 depend on the shared
  resolver change landing (same edit, verified separately).
- T007–T009 are hardening after the behavior tasks are green.
