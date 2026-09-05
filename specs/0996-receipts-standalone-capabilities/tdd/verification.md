# TDD Verification — feature `0996-receipts-standalone-capabilities`

Generated fresh by `zfa tdd verify --feature 0996-receipts-standalone-capabilities`.

## Gate

- gate: `pass`

## Mutation buckets (FR-014)

- killed: 54
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- `B-001` — traces: `FR-001`
- `B-002` — traces: `FR-003`
- `B-003` — traces: `FR-002`
- `B-004` — traces: `FR-005`
- `B-005` — traces: `FR-004`

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 2
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/lib/src/core/plugin_system/capability_invocation_wrapper.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/tdd/services/receipt_preflight.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- exit_code: 0
- elapsed_seconds: 175
- report_path: `/home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-report/mutation-test-report.md`
- preflight_scope_ran (bug #924, per-behavior):
  - `test/commands/capability_command_receipt_hook_test.dart`
  - `test/core/plugin_system/capability_invocation_wrapper_test.dart`
  - `test/plugins/tdd/services/receipt_preflight_test.dart`

## Mutation run

- mutation_was_run: true
- mutation_score: 1.0000

## Evidence binding (bug #837)

- spec_hash: b8f9cd24cdb0d8fd783f67c957292fff4d5f727b70f097ebeebe7410f4db0d95
- subject_hash: `/home/z/my-project/zuraffa/lib/src/core/plugin_system/capability_invocation_wrapper.dart` 8241883dda3b437751ae1b8b181ad48d93efdcfb665aa56d514e3526326f0cd4
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/tdd/services/receipt_preflight.dart` dc4bf4b91a75a224d1a50469f0937cd503f6e5b391e9656f418cd4ec39e01a4c
