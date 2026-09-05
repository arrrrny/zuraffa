---
feature: 0996-receipts-standalone-capabilities
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 77e69f24
updated_at: 77e69f24
suite_baseline: green
---

# Test List: receipts on standalone capability invocations

## Outer loop: acceptance behaviors

One per requirement statement in `spec.md`. Each stays red until the
feature works end to end through its real entry point (the CLI /
`CapabilityInvocationWrapper`).

| id  | behavior                                                                                     | traces  | kind    | state | test                                                                 |
| --- | --------------------------------------------------------------------------------------------- | ------- | ------- | ----- | -------------------------------------------------------------------- |
| A1  | Every successful standalone capability invocation persists a `proof.v1` receipt in `.zfa/receipts/` keyed `<plugin>-<capability>-<entity>-<timestamp>.json` | FR-001  | example | DONE  | `test/core/plugin_system/capability_invocation_wrapper_test.dart` (T001 group) |
| A2  | All twelve listed capabilities emit receipts (di create, cache adapter, repository create, usecase create, service create, datasource create, provider create, shadcn `<layout>`, state create, observer create, sync enable, strategy create) | FR-002  | example | DONE  | `test/commands/capability_receipt_test.dart` (slow tier)              |
| A3  | The stored receipt document is machine-readable: `{plugin, capability, entity, hash, methodset, files, receipt_version: 1}` | FR-003  | example | DONE  | `test/core/plugin_system/capability_invocation_wrapper_test.dart` (T003 group) |
| A4  | `zfa proof check` on a standalone receipt validates: exit 0, JSON verdict `valid: true`; drift fails it | FR-004  | example | DONE  | `test/core/proof/proof_check_valid_test.dart` (real CLI subprocess)   |
| A5  | `zfa tdd verify` includes receipt-checking as a preflight gate; a missing receipt for an audited subject fails the gate before the audit; projects without receipts keep working | FR-005  | example | DONE  | `test/plugins/tdd/services/receipt_preflight_test.dart` (unit + CLI)  |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. The two NEW
source files are the mutation-audit subjects registered in
`tdd/artifacts.json`; the integration matrix and CLI-subprocess tests
are evidence, not mutation subjects (bounded audit, the 041/044
precedent).

### `lib/src/core/plugin_system/capability_invocation_wrapper.dart`

| id  | behavior                                                                          | traces      | kind    | state | test                                                    |
| --- | ---------------------------------------------------------------------------------- | ----------- | ------- | ----- | -------------------------------------------------------- |
| U1  | A file appears in `.zfa/receipts/` after a successful wrapped execution            | FR-001      | example | DONE  | wrapper test `T001 — ... a file appears`                |
| U2  | A failed execution writes no receipt                                               | FR-001      | example | DONE  | wrapper test `a failed execution ...`                   |
| U3  | A successful execution with zero files writes no receipt (issue #769 line)         | FR-001      | example | DONE  | wrapper test `zero files ...`                            |
| U4  | Skipped and deleted actions are excluded (no final bytes from the run)             | FR-001      | example | DONE  | wrapper test `skipped and deleted ...`                   |
| U5  | Receipt persistence is best-effort: an unwritable store warns, the run survives    | FR-001      | example | DONE  | wrapper test `best-effort ...`                           |
| U6  | The receipt hash binds entity + methodset + per-file `(path, action, digest)` — canonical derivation pinned | FR-003 | example | DONE  | wrapper test `hash binds the run ...`                    |
| U7  | methodset from the `--methods` arg; entity from args/result; present-but-empty when no methods | FR-003 | example | DONE  | wrapper test `methodset defaults ...`                  |
| U8  | `execute()` forwards args verbatim and returns the wrapped result                  | FR-001      | example | DONE  | wrapper test `plain capability delegation`               |
| U9  | `CapabilityCommand.run()` executes through the wrapper; pluginId from constructor/parent; failure protocol (exit 1, no receipt) intact | FR-001, FR-002 | example | DONE | `test/commands/capability_command_receipt_hook_test.dart` |

### `lib/src/plugins/tdd/services/receipt_preflight.dart`

| id  | behavior                                                                 | traces  | kind    | state | test                                            |
| --- | -------------------------------------------------------------------------- | ------- | ------- | ----- | -------------------------------------------------- |
| U10 | No receipts shipped → vacuous pass (legacy projects keep working)         | FR-005  | example | DONE  | preflight test `vacuous pass ...`                  |
| U11 | Receipt-covered, valid audited subject → pass, gate active                | FR-005  | example | DONE  | preflight test `receipt-covered ...`               |
| U12 | Missing receipt for an audited subject → GATE FAILURE                     | FR-005  | example | DONE  | preflight test `missing receipt ...`               |
| U13 | Drifted receipt (modified after the run) → GATE FAILURE                   | FR-005  | example | DONE  | preflight test `drifted receipt ...`               |
| U14 | Receipted artifact deleted → GATE FAILURE                                 | FR-005  | example | DONE  | preflight test `receipted artifact deleted ...`    |
| U15 | The gate runs BEFORE the mutation audit in `zfa tdd verify` (exit 1, no audit start) | FR-005 | example | DONE | preflight test CLI group                          |
