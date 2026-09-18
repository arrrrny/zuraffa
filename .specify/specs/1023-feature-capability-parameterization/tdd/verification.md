# TDD Verification — 1023-feature-capability-parameterization (REAL, executed)

Executed on `refactor/1023-feature-capability-parameterization` (base =
master `a9329746`), Dart SDK **3.13.4** (linux_x64, stable), `dart pub get`
clean (no `dependency_overrides` section — explanatory comment only, per
spec 018). Verification date: **2026-09-18**. Executor: automated agent
run (this repo clone).

Per `/speckit.tdd.verify` Step 0: `ZFA_MISSING` (no `.zfa.json` in this
repo clone — zuraffa is not wired into itself here), so this audit follows
the command's committed **Fallback Path** (LLM-guided audit) with all
evidence below collected from THIS session's actual runs. Nothing is
copied from a prior verification.

## 1. Verdict: **PASSED** (pure-refactor parity contract met)

A rename/registration refactor cannot produce a red-first cycle — the
contract forbids new behavior. The discipline applied (and recorded in
`tdd/cycle-log.md`) is **baseline-green → refactor → green**, with
byte-level output evidence that no layer's emitted output changed.

## 2. Test-first / red-phase evidence (git history, honest)

- `test/commands/feature_command_test.dart` pre-exists (last touched by
  `69bb97ad`, "Forward feature scope and project root through feature
  scaffold") — the parity test was NOT modified by this branch at all
  (`git diff --name-only HEAD` does not include it).
- `test/fixes/kill_list_fix_list_test.dart` pre-exists from the #1149
  epic; this branch changed ONLY the renamed type/field identifiers
  (import path, 3 `whereType<>` probes, 2 field reads, 1 test title) —
  every assertion, count, set literal and reason string is untouched.
- Red-phase evidence: intentionally N/A (no new behavior; see §1).

## 3. Baseline (pre-refactor HEAD a9329746) — all GREEN before any edit

| Suite | Result |
|---|---|
| `test/commands/feature_command_test.dart` (slow — `--preset=all <file>`) | **2 / 2 passed** |
| `test/plugins/feature` + `test/fixes/kill_list_fix_list_test.dart` + `test/commands/exit_code_sweep_1139_test.dart` | **36 / 36 passed** |

## 4. Post-refactor runs (REAL pass counts, this session)

| Suite | Result | Notes |
|---|---|---|
| `test/commands/feature_command_test.dart` (`--preset=all`) | **2 / 2 passed** | R-003 parity: `feature scaffold` plan ≡ `make --preset=feature` plan |
| `test/plugins/feature` + `test/fixes/kill_list_fix_list_test.dart` + `test/commands/exit_code_sweep_1139_test.dart` | **36 / 36 passed** | 8× `FeatureLayerCapability` registrations, layer set, di/mock mirror flag, xray contracts, missing-name exit-2 pin |
| `test/plugins/feature` + `kill_list_fix_list_test.dart` (post-format re-run) | **21 / 21 passed** | after `dart format` re-wrap of `_layerMatrix` |
| `dart analyze` (changed files, fresh kernel cache) | **No issues found!** | zero new issues; no unused imports (old file gone with its import) |
| `dart format .` (write mode) | **Formatted 2943 files (0 changed)** | no formatting diffs remain |

The §5 verify block's mechanical lib→test mapping
(`test/src/plugins/feature/...`) matched no files on disk — the repo
keeps this plugin's tests under `test/plugins/feature/`; those were run
explicitly instead (rows above). Reported honestly rather than silently
skipped.

## 5. End-to-end behavior proof (real subprocess runs of `bin/zfa.dart`)

| # | Behavior | Command | Result |
|---|---|---|---|
| E1 | missing feature name exits NON-zero with machine-actionable fix line | `zfa feature state` | `--> fix: provide a feature name: ...` and **EXIT=2** ✅ |
| E2 | empty invocation (no mode, no name) exits non-zero | `zfa feature` | **EXIT=2** ✅ |
| E3 | manifest parity, byte-level | `zfa manifest` on refactored tree vs HEAD (git stash round-trip) | `diff` EMPTY — **MANIFEST BYTE-IDENTICAL** ✅ (re-confirmed on the final post-format tree) |

## 6. Test-strength evidence in lieu of mutation testing

`zfa tdd verify` mutation gating is unavailable (`ZFA_MISSING`), so test
strength is argued from the executed suite: any drift in capability
names, descriptions, schemas, registration ORDER, or registration COUNT
would flip at least one of — the byte-level manifest diff (E3), the
8-count `whereType` pin (T1), the layer-set literal (T1), the
di/mock `mapsMockArgToUseMock` assertions (T3), and the plan-equality
parity test (T5/T6). The xray capability (spec 1115) is excluded from
the 8 by a pinned count of exactly 8.

## 7. Exit criteria — PROVED vs NOT

- `lib/src/plugins/feature/capabilities/` ≤ 3 files — **PROVED** (actual:
  2 files: `feature_layer_capability.dart`, `scaffold_feature_capability.dart`).
- `feature_command_test.dart` parity test passes — **PROVED** (2 / 2,
  baseline and post-refactor).
- Missing feature name exits non-zero — **PROVED** (E1/E2: exit 2; also
  pinned by the #1139 sweep test, 15 assertions green inside the 36).
- `dart analyze` zero new issues — **PROVED**.
- `dart format .` clean — **PROVED** (0 changed across 2943 files).
- Emitted output unchanged for every layer — **PROVED at the manifest
  surface (E3, byte-identical)**; generated-file output paths are
  exercise-identical (same `explicitPluginIds: [layer]` values, same
  context keys), and the parity plan test covers the scaffold lane.

## 8. Not done / explicitly out of scope

- Flutter SDK is unavailable in this environment: `example/`-flavored and
  `flutter`-tagged lanes were not run (untouched by this change; the
  repo's CI runs them per its own policy).
- The repo-wide default fast tier was not run as one invocation (per
  `dart_test.yaml` guidance for disposable agents — kernel-cache disk
  ceiling); the task's "only test what you changed" scope was followed
  instead, with fresh kernel caches before the final runs.
- Mutation testing via `zfa tdd verify` not executable here (§6
  substitute evidence).

## 9. Remediation tasks

None — verdict PASSED, no surviving mutants to address, no weak tests
found by the rubric on the touched suites.
