---
feature: 0974-di-a-plus-upgrade
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: 0974-di-a-plus-upgrade
updated_at: 0974-di-a-plus-upgrade
suite_baseline: green (chunked fast tier, base 77e69f24)
---

# Test List: 0974-di-a-plus-upgrade (issue #974)

Baseline: fast tier green at branch point `77e69f24` (master), `dart analyze`
345 issues (all pre-existing infos). All new tests live under
`test/plugins/di/` per the issue's constraint and are hermetic
(temp-dir fixtures, no Flutter).

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | `grep -r "di_command.dart"` returns nothing — the 427-LOC dead command is gone from the tree and nothing references it. | AC-1 | example | DONE | `test/plugins/di/dead_command_gone_test.dart` |
| A2 | `zfa di verify` catches a deliberately dangling `getIt<Missing>()` registration — exit 1, `--> fix:` naming the class and expected file; a clean tree verifies green. | AC-2 | example | DONE | `test/plugins/di/di_verify_test.dart` |
| A3 | Standalone `di create` writes a receipt under `.zfa/receipts/` (registrations + index hashes); `zfa proof check` (ProofChecker) is green afterwards. | AC-3 | example | DONE | `test/plugins/di/di_receipts_test.dart` |
| A4 | A forced generation failure returns `success: false` (no more hardcoded success), and non-fatal skips surface as structured `{target, reason}` warnings. | AC-4 | example | DONE | `test/plugins/di/di_verdicts_test.dart` |

## Inner loop: unit behaviors

| id | behavior | traces | state | test |
| -- | -------- | ------ | ----- | ---- |
| U1 | No `.dart` file under `lib/` contains the token `di_command.dart` (import or comment). | AC-1 | DONE | `test/plugins/di/dead_command_gone_test.dart::grep gate` |
| U2 | The verify gate indexes classes on disk and resolves every `getIt<T>()` / `getIt.registerXxx<T>()` type reference in `lib/src/di/**`; a missing `di/` tree verifies green (nothing to check). | AC-2 | DONE | `test/plugins/di/di_verify_test.dart` |
| U3 | Dangling bindings report file + class + expected conventional file with a `--> fix:` hint, and fail the verdict (success: false). | AC-2 | DONE | `test/plugins/di/di_verify_test.dart` |
| U4 | `zfa di register` also writes a standalone receipt (registrations + index hash) via `ReceiptStore`. | AC-3 | DONE | `test/plugins/di/di_receipts_test.dart` |
| U5 | Receipts bind final on-disk bytes (sha256) so `ProofChecker` passes on a fresh run, and dry-run/revert runs write no receipt. | AC-3 | DONE | `test/plugins/di/di_receipts_test.dart` |
| U6 | `ExecutionResult` carries structured warnings as `{target, reason}` entries, serialized in `toJson()`. | AC-4 | DONE | `test/plugins/di/di_verdicts_test.dart` |
| U7 | A generation exception surfaces as `success: false` with the failure message instead of an unhandled crash or a false success. | AC-4 | DONE | `test/plugins/di/di_verdicts_test.dart` |

## Routing provenance

route: A1 -> acceptance lane [declared: issue #974 order 1]
route: A2 -> acceptance lane [declared: issue #974 order 2]
route: A3 -> acceptance lane [declared: issue #974 order 3]
route: A4 -> acceptance lane [declared: issue #974 order 4]
route: U1..U7 -> unit lane [declared: issue #974 order 6, tests under test/plugins/di/]
