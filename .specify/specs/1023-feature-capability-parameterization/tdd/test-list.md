# Test List: 1023-feature-capability-parameterization

Pure refactor — the behaviors below are the parity contract. Baseline was
collected BEFORE the rename (all green on HEAD = a9329746); the same
behaviors must be green after. There is no red-first cycle by design: the
contract explicitly forbids behavior change, so the loop is
baseline-green → refactor → green (recorded in cycle-log.md).

## Behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T1 | all 8 single-plugin feature capabilities are registrations of the ONE parameterized class (`FeatureLayerCapability`) — `whereType` count == 8, layer set == {di, view, presenter, controller, route, state, mock, test} | R-001, kill_list_fix_list_test (fix 3) | BASELINE GREEN → GREEN |
| T2 | MCP-visible capability names preserved: scaffold + the 8 layers (+ xray) appear by name in `plugin.capabilities` | R-005, kill_list_fix_list_test (fix 3) | BASELINE GREEN → GREEN |
| T3 | the `di` capability mirrors `mock` onto `use-mock`; the `mock` capability does not (`mapsMockArgToUseMock`) | R-005, kill_list_fix_list_test (fix 3) | BASELINE GREEN → GREEN |
| T4 | layer matrix is the single source of registrations: manifest output (names, descriptions, schemas, order) is BYTE-IDENTICAL before/after the refactor (`zfa manifest` diff on stashed HEAD vs refactored tree) | R-002, R-005, real diff evidence | NEW EVIDENCE |
| T5 | `zfa feature scaffold Product --plan --format=json` resolves through the same normalized plan as `zfa make Product --preset=feature ... --plan --format=json` (plans equal) | R-003, feature_command_test.dart (slow — run via `--preset=all <file>`) | BASELINE GREEN → GREEN |
| T6 | feature forwards feature scope and project root to make (second parity test in the same file) | R-003, feature_command_test.dart (slow) | BASELINE GREEN → GREEN |
| T7 | missing feature name is a usage error, never a lying exit 0 — pinned assertion `ExitProtocol.usage` + `Missing feature name` output | R-004, exit_code_sweep_1139_test.dart | PRE-EXISTING GREEN → re-proved by real CLI run |
| T8 | real CLI: `zfa feature state` (mode, no name) exits 2 with the machine-actionable fix line; `zfa feature` (empty rest) exits 2 | R-004, subprocess run of `bin/zfa.dart` | NEW EVIDENCE |
| T9 | `lib/src/plugins/feature/capabilities/` contains at most 3 files (actual: 2 — `feature_layer_capability.dart`, `scaffold_feature_capability.dart`; `xray_feature_capability.dart` lives one level up by design, spec 1115) | R-006, directory listing | PROVED |
| T10 | `dart analyze` over changed files: zero issues; `dart format .`: no diffs | exit criteria, analyze/format | PROVED |

## Functional Requirements

- **FR-001**: One parameterized capability
  `FeatureLayerCapability(layer: String)` replaces the 8 former clones;
  per-layer registration behavior identical (issue #1023 deliverable 1).
- **FR-002**: The layer matrix is registered in the plugin manifest —
  `FeaturePlugin._layerMatrix` rows drive the `capabilities` getter
  (issue #1023 deliverable 2).
- **FR-003**: `feature_command_test.dart` parity test passes unchanged
  (issue #1023 deliverable 3).
- **FR-004**: Missing feature name exits non-zero (issue #1023
  deliverable 4 — fix verified as already landed via #1139; re-proved by
  a real run, no code change needed).

## Mutation-strength note (TDD extension rubric)

A rename refactor cannot demonstrate mutation-killing tests for NEW
behavior — there is no new behavior. Test strength for this spec is the
byte-level manifest diff (T4) plus the pre-existing contract suites
(T1–T3, T5–T7): any drift in names, order, descriptions, schemas, or
registration counts would fail at least one of them.
