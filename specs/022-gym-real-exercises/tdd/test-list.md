# TDD Test List — Build Real GYM Exercises

**Spec**: `specs/022-gym-real-exercises/spec.md`
**Plan**: `specs/022-gym-real-exercises/plan.md`
**Tasks**: `specs/022-gym-real-exercises/tasks.md`

## Behaviors

### B01 — DROP CARD has all four required fields

- **Spec**: FR-006, US-4 scenario 1, SC-004
- **Test**: `test/plugins/gym/drop_card_test.dart` — `DROP CARD has Did/Expected/Happened/Where`
- **Implementation**: `.gym/lib/drop_card.dart` — `DropCard.emit`

### B02 — DROP CARD throws if any field is missing

- **Spec**: FR-006, US-4 scenario 1
- **Test**: `test/plugins/gym/drop_card_test.dart` — `missing field throws ArgumentError`
- **Implementation**: same — `DropCard.emit` validates inputs

### B03 — DROP CARD writes to a file

- **Spec**: FR-006, US-4 scenario 2
- **Test**: `test/plugins/gym/drop_card_test.dart` — `writeTo produces a markdown file`
- **Implementation**: same — `DropCard.writeTo`

### B04 — zuraffa's existing warmup reps still pass (no regression)

- **Spec**: FR-008, US-3 scenario 3, SC-003
- **Test**: existing `.gym/warmup/{01-deps,02-build,03-smoke}.dart` files unchanged + still exit 0
- **Implementation**: no changes to existing warmup files

### B05 — zuraffa's existing graded exercises still pass (no regression)

- **Spec**: FR-008, SC-003
- **Test**: existing `.gym/exercise-{generate-feature,agent-rewrite-zfa-only}.dart` files unchanged + still listed in `gym.yaml`
- **Implementation**: no removals from `gym.yaml`

### B06 — New zuraffa exercise (`extend-zfa-cli`) is a genuine dev task

- **Spec**: FR-003, US-2 scenario 1
- **Test**: `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — exercise structure is correct (sandbox, assertion, DROP CARD path)
- **Implementation**: `.gym/exercise-extend-zfa-cli.dart`

### B07 — `extend-zfa-cli` is registered in `gym.yaml`

- **Spec**: FR-004, US-3 scenario 1
- **Test**: `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — `gym.yaml` contains the `extend-zfa-cli` entry
- **Implementation**: `.gym/gym.yaml` — append exercise entry

### B08 — `extend-zfa-cli` emits a DROP CARD on mis-fire

- **Spec**: FR-006, US-4 scenario 1
- **Test**: `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — mis-fire path produces a DROP CARD with all four fields
- **Implementation**: `.gym/exercise-extend-zfa-cli.dart` — calls `DropCard.emit` on assertion failure

### B09 — zorphy reference template has warmup + graded exercise

- **Spec**: FR-001, FR-002, FR-003, US-1 scenario 2, US-2 scenario 2
- **Test**: `test/plugins/gym/gym_templates_test.dart` — zorphy template has 3 warmup reps + 1 graded exercise
- **Implementation**: `examples/gym-templates/zorphy/.gym/`

### B10 — zikzak_inappwebview reference template has warmup + graded exercise

- **Spec**: FR-001, FR-002, FR-003, US-1 scenario 3, US-2 scenario 3
- **Test**: `test/plugins/gym/gym_templates_test.dart` — zikzak_inappwebview template has 3 warmup reps + 1 graded exercise
- **Implementation**: `examples/gym-templates/zikzak_inappwebview/.gym/`

### B11 — vendure-flutter-sdk reference template has warmup + graded exercise

- **Spec**: FR-001, FR-002, FR-003, US-1 scenario 4, US-2 scenario 4
- **Test**: `test/plugins/gym/gym_templates_test.dart` — vendure-flutter-sdk template has 3 warmup reps + 1 graded exercise
- **Implementation**: `examples/gym-templates/vendure-flutter-sdk/.gym/`

### B12 — Every gym.yaml has the canonical miki-consumable shape

- **Spec**: FR-004, US-3 scenario 1
- **Test**: `test/plugins/gym/gym_templates_test.dart` — every gym.yaml has `name`, `version`, `warmup`, `exercises`; each exercise has `id`, `brief`, `setup`, `verifyCommand`, `evaluate`
- **Implementation**: every `gym.yaml` file

### B13 — Exercises run in isolated sandboxes (FR-005)

- **Spec**: FR-005, US-2 (implicit)
- **Test**: `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — sandbox is under `.gym/.sandbox/` and source tree is unchanged after exercise run
- **Implementation**: every exercise writes under `.gym/.sandbox/<exercise-id>/`

### B14 — Grading is exit-code-based (FR-007)

- **Spec**: FR-007, US-4 scenario 2
- **Test**: `test/plugins/gym/extend_zfa_cli_exercise_test.dart` — pass path exits 0; mis-fire path exits non-zero
- **Implementation**: every exercise uses `exit(0)` on pass, `exit(1)` on mis-fire

### B15 — Mis-fire DROP CARD includes `Where` field naming the failing stage

- **Spec**: FR-006, US-4 scenario 1
- **Test**: `test/plugins/gym/drop_card_test.dart` — `Where` field contains a stage identifier (e.g. "spawn", "assert", "stdout-check")
- **Implementation**: every exercise's mis-fire path passes a stage identifier to `DropCard.emit`

### B16 — `examples/gym-templates/README.md` documents how to consume templates

- **Spec**: FR-013 (implicit — adoption), Edge Cases (miki version mismatch)
- **Test**: `test/plugins/gym/gym_templates_test.dart` — README exists + covers copy-paste instructions
- **Implementation**: `examples/gym-templates/README.md`

---

## Red Evidence

For each behavior, the test file was written **before** the
implementation file existed. The first run produced a red exit (failed
import or `not found` for the unimplemented symbol). See
`tdd/verification.md` for the per-behavior red → green transition
record.

## Mutation Check

The `mutation_test` framework (spec 041) is wired to the TDD plugin;
this feature's per-behavior mutation budget is out of scope. The
behaviors above are specification-driven: a mutation that drops the
`Where` field from a DROP CARD is caught by B15; a mutation that
returns exit 0 on mis-fire is caught by B14; a mutation that removes
the sandbox isolation is caught by B13.
