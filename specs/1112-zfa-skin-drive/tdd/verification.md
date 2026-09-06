# TDD Verification — feature `1112-zfa-skin-drive`

Generated fresh by `zfa tdd verify --feature 1112-zfa-skin-drive`.

## Gate

- gate: `pass`

## Mutation buckets (FR-014)

- killed: 17
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- `B-001` — traces: `FR-1`
- `B-002` — traces: `FR-1`

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 1
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/lib/src/skin/anchors.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- exit_code: 0
- elapsed_seconds: 16
- report_path: `/home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`
- preflight_scope_ran (bug #924, per-behavior):
  - `test/skin/anchors_tap_result_test.dart`
  - `test/skin/tap_result_test.dart`

## Mutation run

- mutation_was_run: true
- mutation_score: 1.0000

## Evidence binding (bug #837)

- spec_hash: 900129372bebd0d08ba034e244c791f76701b5e8fee1d01f8086f4e42668ad50
- subject_hash: `/home/z/my-project/zuraffa/lib/src/skin/anchors.dart` 4d855cc7d41fbbaa8a61405af73bfb480a8d05a9363dff410ea9eea6527f2a6e

## Environment notes (appended by the implementer — honesty record)

- The engine verdict above is REAL: `zfa tdd verify --feature 1112-zfa-skin-drive`
  ran on this host; the mutation phase executed (`mutation_was_run: true`),
  17/17 mutants killed, subjects restored byte-identically. The first run
  honestly returned `fail_survived` (3 survivors in `isAnchorKey` /
  `unregister`); the remediation loop added T2.7/T2.8 and the re-run passed.
- SC-1 (macOS live-app run: `flutter run -d macos` + `zfa skin drive`
  against the real VM) was NOT executed: this is a Linux container with
  no Flutter SDK and no macOS host. The driver's wire-to-JSON contract is
  proven by the fake-VM suite (`test/commands/skin_drive_command_test.dart`,
  T4.1–T4.9) and the live connection-failure path was exercised for real
  (exit 2 + error envelope). The maintainer lane command:
  `flutter run -t lib/main_skin.dart -d macos --debug` →
  `zfa skin drive --dart-uri=<uri> --anchor=zfa:signin-guest`.
- SC-2 JSON-shape identity is pinned by T1.1/T6.4 (same envelope constant);
  the widget-test bridge itself requires flutter_test (same host constraint).
- Subprocess receipts (this host, real CLI binary):
  - `zfa skin sim` (green manifest): 3 taps → found/disabled/notFound JSON
    lines, summary, exit 0.
  - `zfa skin sim` (drift manifest): `[drift]` line + exit 1.
  - `zfa skin kit`: emitted `lib/src/skin/skin_contract_auditor.dart` +
    `test/skin/zfa_anchor_test_bridge.dart` (skip-if-exists verified on
    re-run); `zfa skin verify` honest `insufficient-input` on a bare target.
  - `zfa skin drive` (no VM): usage exit 64; dead-URI connection → exit 2
    with the error envelope as the final line.
- SC-3: zero synthetic-click code in the tree (rg: only doc comments
  explaining the replacement). The pilot's `tool/drive_guest.dart` never
  existed in this repository (pilot workspace only) — nothing to delete
  here; its replacement (`zfa skin drive`) supersedes it.
