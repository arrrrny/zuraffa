# Tasks: Standalone Zero-Artifact Honesty — `test create` / `api` Verbs

**Input**: [spec.md](spec.md) · [plan.md](plan.md) · **Tests**: [tdd/test-list.md](tdd/test-list.md)

## Phase 1 — RED (tests before implementation)

- [x] **T001** (P1) Regression `test/regression/issue_1385_1386_zero_artifact_honesty_test.dart`: fresh pure-Dart package → `zfa test create Product` exits non-zero, prints `❌` + `--> fix:` naming the missing UseCase source; no `✅ Success!` line. MUST FAIL pre-fix.
- [x] **T002** (P1) Regression `test/regression/issue_1385_1386_zero_artifact_honesty_test.dart`: fresh pure-Dart package → `zfa api Product` exits non-zero, prints `❌ Failed to generate API bridge`. MUST FAIL pre-fix.
- [x] **T003** (P1) Benign pins in the same two files: overwrite-conflict-only `test create` run exits 0 (with `--force` hint listing); `--dry-run` forms of both verbs exit 0.

## Phase 2 — Structured skip causes (non-behavioral groundwork)

- [x] **T004** (P1) `lib/src/models/generated_file.dart`: add optional `String? skipReason`; serialize in `toJson()` when non-null. Source-compatible.
- [x] **T005** (P1) `test_builder_entity.dart`: `skipReason: 'missing-dependency'` on UseCase-file + native-mock skips; `'overwrite-conflict'` on existing-target skips.
- [x] **T006** (P1) `test_builder_custom.dart` + `test_builder_polymorphic.dart`: same tagging for their dependency-missing / existing-target skips.

## Phase 3 — GREEN (verdict gates)

- [x] **T007** (P1) `create_test_capability.dart`: zero-artifact + missing-dependency skip + non-dry-run ⇒ `success: false` + honest `message` (cause + `--> fix:`). T001/T003 green.
- [x] **T008** (P1) `create_api_bridge_capability.dart`: zero-file non-dry-run ⇒ `success: false` + honest `message`. T002 green.

## Phase 4 — Cross-artifact & fleet checks

- [x] **T009** (P2) `/speckit.analyze` pass: spec ↔ plan ↔ tasks ↔ tests consistency; verify no receipt-contract (#769) regression and no new exit classes (#767 family intact).
- [x] **T010** (P2) Run the touched-verb test surface: `dart test test/regression/issue_1385_1386_zero_artifact_honesty_test.dart` + existing test-plugin and api-plugin suites (fast tier) — zero new failures.
- [x] **T011** (P2) `dart format .` clean; `dart analyze` clean on the six touched files.

## Phase 5 — TDD verification

- [x] **T012** (P2) `tdd/verification.md`: red evidence (pre-fix failures), green evidence (post-fix passes), acceptance-criteria coverage map (SC-1..SC-4).

## /speckit.analyze — cross-artifact consistency (post-implementation pass)

- **spec ↔ tests**: SC-1..SC-4 covered; one documented deviation — the two planned test files were combined into a single file (`issue_1385_1386_zero_artifact_honesty_test.dart`, two groups) to keep the misfire provenance visible; SC references unaffected.
- **US3 CLI pin deviation (accepted)**: no current code path emits an overwrite-conflict skip entry for the test verb, so the benign half of the truth table is pinned structurally (gate predicate fires only on `skipReason == 'missing-dependency'`) plus the dry-run CLI pins. Recorded honestly in tdd/verification.md §3.
- **plan ↔ code**: `package:path` import added to `create_test_capability.dart` (not in plan's file list) — trivial, recorded. All other touched files match the plan.
- **Receipt contract (#769)**: unchanged; zero-artifact runs persist no receipt both before and after. **Exit-code treaty (#767/#917)**: reuses the existing `exitCode = 1` failure branch; no new exit class.
- **Fleet check**: `zfa make` orchestrator path untouched (`TestPlugin.generate` unchanged — only the standalone capability verdict gate changed), so misfire #1387's asymmetry is not widened.
- **No drift found** requiring spec changes.
