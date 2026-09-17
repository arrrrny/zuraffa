# TDD Verification — feature `001-login`

Generated fresh by `zfa tdd verify --feature 001-login`.

## Gate

- gate: `pass`

## Mutation buckets (FR-014)

- killed: 1
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- `A1` — traces: `AC-1`
- `U1` — traces: `FR-001, AuthRepo.login`

## Behavior kinds (issue #1376)

- presence: 0
- absence: 0
- route-outcome: 0
- enabled-state: 0
- sequence: 0

- `A1` — not traced: no scenario-assertions header in test/tdd/001-login/a1_test.dart
- `U1` — not traced: no scenario-assertions header in test/tdd/001-login/u1_test.dart

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 2
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/probe/login_probe/lib/tdd/001-login/a1_subject.dart`
  - `/home/z/my-project/probe/login_probe/lib/tdd/001-login/u1_subject.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- exit_code: 0
- elapsed_seconds: 6
- report_path: `/home/z/my-project/probe/login_probe/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`
- preflight_scope_ran (bug #924, per-behavior):
  - `test/tdd/001-login/a1_test.dart`
  - `test/tdd/001-login/u1_test.dart`

## Mutation run

- mutation_was_run: true
- mutation_score: 1.0000

## Evidence binding (bug #837)

- spec_hash: 8d4257afdeda3491003066b62f584f725dd541170833b83e4463b7142dc6184a
- subject_hash: `/home/z/my-project/probe/login_probe/lib/tdd/001-login/a1_subject.dart` b843d5fbf4fd8a4acec4103a58e3aff3ab6a0e7dc3ab17d83140849a2460ad21
- subject_hash: `/home/z/my-project/probe/login_probe/lib/tdd/001-login/u1_subject.dart` 600b738d54843f055491d0c19c96346301337fde5cfd4a4c96965831ff7abb8e
