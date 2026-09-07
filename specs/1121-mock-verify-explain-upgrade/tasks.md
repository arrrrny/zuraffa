# TASKS — SPEC 1121 (mock verify + explain)

Dependency-ordered, MVP-first: the verify command (orders 1–2) lands before explain
(order 3); every behavior task is traced to its failing test (T005–T009) before implementation.

## Phase A — behavioral core (TDD, red → green)

- [x] **T001 (behavior, AC-1/AC-5)** `MockVerifyCommand` verifies a conforming on-disk mock:
      exit 0, conformance line naming interface class + registry id, zero writes to the tree.
      Test: `mock_verify_test.dart › A1 pass path`.
- [x] **T002 (behavior, AC-2)** Drift detection: a mock missing an interface member exits 1
      with a `--> fix:` line naming the member and the interface; an analyze error also exits 1.
      Test: `mock_verify_test.dart › A2 drift path`.
- [x] **T003 (behavior, AC-3)** No-mock refusal: exit 1, `missing_file` finding, fix line
      naming `zfa mock create <Entity> --certify`.
      Test: `mock_verify_test.dart › A3 no-mock refusal`.
- [x] **T004 (behavior, AC-4)** `--json` canonical envelope: pass and fail envelopes parse via
      `VerdictEnvelope.fromJson`, schema `zuraffa.verdict.v1`, correct verdict/exit_class/
      subject/findings/drifts.
      Test: `mock_verify_test.dart › A4 --json paths`.
- [x] **T005 (behavior, AC-6)** `MockExplainCapability`: coverage, skipped/invented lists,
      per-method certification status from the committed receipt, registry id.
      Test: `mock_verify_test.dart › A5 explain`.
- [x] **T006 (behavior, AC-6)** Selector bindings (#1034): explain reports the
      `MockData.forMethod` selector declaration (declared/discriminator type) and the
      `forMethod(params.<field>)` bindings found on disk.
      Test: `mock_verify_test.dart › A5 explain (selector section)`.
- [x] **T007 (behavior, AC-7)** `mock explain --json`: the full report under the canonical
      envelope's `details.explain`.
      Test: `mock_verify_test.dart › A6 explain --json`.

## Phase B — wiring & grammar (non-behavioral)

- [x] **T008** Register `MockVerifyCommand` + `MockExplainCommand` as manual subcommands of
      `MockCommand` (`manualSubcommandNames` gains `verify`, `explain` — issue #761 collision
      guard); add `MockExplainCapability` to `MockPlugin.capabilities` for manifest visibility.
- [x] **T009** Grammar/schema consistency: `--json` is an output-envelope flag on both verbs;
      `--project`/`--verbose` on verify; `--project` on explain; usage errors exit 2 with fix
      lines. Covered by the usage assertions inside `mock_verify_test.dart`.
- [x] **T010** Docs: `CLI_GUIDE.md` mock section gains `verify`/`explain` entries (grammar,
      exit codes, envelope shape).

## Phase C — verification & evidence

- [x] **T011** `dart analyze` over the changed files: clean.
- [x] **T012** `dart test test/plugins/mock/mock_verify_test.dart`: green (report ACTUAL
      pass/fail counts).
- [x] **T013** `dart format .`: zero remaining formatting diffs (CI format gate).
- [x] **T014** `tdd/verification.md`: test-first evidence + acceptance-criteria coverage table.
- [x] **T015** Commit spec-kit artifacts with the code; push; PR to `master`.
