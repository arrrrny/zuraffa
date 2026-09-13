# Bug Test Audit: 1574-tdd-gen-relative-paths

- **Slug**: 1574-tdd-gen-relative-paths
- **Date**: 2026-09-14 (post-fix audit)
- **Auditor**: /speckit-bug-test (verification pass over the TDD cycle's output)

## What was verified (all commands below were actually run on this branch)

### 1. The fix's own guard suite — `dart test test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`

- Result: **6/6 pass** (`00:00 +6: All tests passed!`)
- Covers: relative persist form (specs + bug lanes), relative emitted
  record/verdict form (both lanes), re-gen reuse against a relative prior
  record in the bug lane, and the committed-registry census guard.

### 2. RED evidence integrity (recorded pre-fix, 2026-09-13)

- `dart test test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`
  at pre-fix HEAD: **1 pass / 5 fail**. The failing set was exactly the issue's
  behavior set:
  - bug lane fresh gen persisted `/tmp/…/test/tdd/…` (machine-absolute — the
    live corruption),
  - stdout record carried absolute forms in both lanes,
  - bug-lane re-gen refused with the verbatim issue text: `ownership
    conflict — OwnershipConflict: the registry test path "test/tdd/
    100-feature-one/a1_test.dart" does not match "/tmp/…/test/tdd/
    100-feature-one/a1_test.dart"`,
  - committed census counted the 10 drifted registries.
- The one pre-fix pass (specs-lane persist) is the #1397 canonicalization net
  — the issue itself acknowledges persist is masked in that lane; the guard
  stays as a regression pin.

### 3. Regression scope (changed code: gen_command.dart, artifact_registry.dart)

- Targeted suites:
  `dart test test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart
  test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart
  test/plugins/tdd/commands/bug_1573_doctor_migrate_prescription_test.dart
  test/plugins/tdd/services/artifact_registry_test.dart
  test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart
  test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart`
  → **46/46 pass**.
- Full changed-scope chunk: `dart test test/plugins/tdd/commands/` →
  **584/584 pass** (`00:05:34 +584: All tests passed!`). This includes every
  ownership-gate suite (#835/#840/#1495/#1380/#1375), the doctor/migrate
  suites (#1397/#1573), the gen seam suites (#1272/#1518) and the run-driver
  handoff suites.
- Wider fast tier via the repo's disk-safe chunked runner
  (`tools/run_tests_chunked.sh`, kernel cache cleared per chunk): all chunks
  pass EXCEPT the pre-existing environment failures listed below —
  including the whole `test/plugins/tdd/` tree (services, models, theater,
  corpus_economics, ci_referee, tier2_firestore), `test/core`, `test/domain`,
  `test/engine`, `test/plugins/*` (mock, mcp, route, slice, state, skin,
  xray, …), `test/tdd/*` committed-artifact suites (004, 072, 073, 074,
  078, 079, 0966, 1334, 1444, cycle-log-phantom-sections,
  bug-tdd-run-baseline-timeout).

### 4. Static analysis + format gate

- `dart analyze` on the three changed files → `No issues found!`
- `dart format lib/src/plugins/tdd/commands/gen_command.dart
  lib/src/plugins/tdd/services/artifact_registry.dart
  test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart` → applied;
  repo-scan `dart format --output=none --set-exit-if-changed lib/
  test/plugins/tdd/commands/` → 1345 files, **0 changed** (exit 0).

### 5. Data migration audit

- Pre-migration census (per-record, not per-registry): 10 registries carrying
  machine-absolute `test_path`/`subject_path` fields (107 records); 7
  relative registries; 1 empty.
- Post-migration census: **0 records with an absolute path field across all
  18 tracked registries**.
- Migration diff is form-only: 11 files changed, 11 insertions, 11 deletions
  (one line per registry — compact JSON byte format preserved); no artifact
  file touched, no registry structure changed.

## Pre-existing failures NOT caused by this fix (flagged honestly)

All were proven pre-existing by running them against pristine `master`
(82b9ffe2) or by their nature:

1. `test/plugins/presenter/presenter_compile_test.dart`,
   `test/plugins/view/view_compile_test.dart`,
   `test/templates/self_hosting/downstream_compile_gate_test.dart` —
   `ProcessException: No such file or directory: flutter pub get --no-example`
   — these suites require the Flutter SDK, absent on this agent.
2. `test/tdd/077-make-engine-preset/a1_test.dart` —
   `UnimplementedError: subject_a1 not implemented`. Reproduced identically on
   a pristine master worktree: the committed subject is a GENERATED STUB whose
   header states the pair is honest-red on first execution — by design, in the
   slow tier.
3. `test/plugins/tdd/scenarios/` — slow-tier acceptance scenarios (real
   subprocess temp projects); excluded on cloud agents per dart_test.yaml's
   own policy, not run here.
4. A single whole-tree `dart test test/plugins/tdd/` invocation is not usable
   on this disk class (kernel cache overflows; dart_test.yaml documents the
   chunked runner for this) — the chunked runner was used instead.

## Verdict

- Reproduction case: no longer fails (red → green, both surfaces).
- New/updated tests: 6/6 pass.
- Regression suite: green in scope (584/584 commands chunk + 46/46 targeted;
  wider fast tier green chunk-by-chunk).
- Acceptance criteria 1–4: PROVED (see fix.md).
