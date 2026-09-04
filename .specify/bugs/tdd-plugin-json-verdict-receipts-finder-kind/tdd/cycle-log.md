# TDD Cycle Log: TDD Plugin --json Verdict Envelope + Receipts

**Started**: 2026-09-04
**Source spec**: spec.md
**Test list**: ./test-list.md

## Baseline (2026-09-04)

- No `VerdictEnvelope` model exists in `lib/src/plugins/tdd/models/`.
- 0 of 25 TDD commands register a `json` flag.
- Only `gen` and `reset` emit JSON unconditionally (no flag).
- Only `realize` writes #807 receipts.

## GREEN Evidence — 2026-09-04

### U1-U3: VerdictEnvelope model
- File: `lib/src/plugins/tdd/models/verdict_envelope.dart` — created
- File: `test/plugins/tdd/verdict_envelope_test.dart` — 6 tests, all GREEN
- `dart test test/plugins/tdd/verdict_envelope_test.dart` → All tests passed!

### U4-U18: --json flag on 15 leaf commands
- File: `test/plugins/tdd/json_flag_test.dart` — 15 tests, all GREEN
- `dart test test/plugins/tdd/json_flag_test.dart` → All tests passed!
- Commands wired: run, plan, gen, make, view, realize, verify, verify-red, init, compose, refactor, reset, wire, fake, func
- `dart test test/plugins/tdd/verdict_envelope_test.dart test/plugins/tdd/json_flag_test.dart` → 21 passed

### FR-3: gen/reset JSON gated on --json
- gen_command._printBatchVerdict gated on `_jsonMode` (text fallback when --json absent)
- gen_command._printVerdict gated on `_jsonMode` (text fallback when --json absent)
- reset_command._printVerdict gated on `_jsonMode` (text fallback when --json absent)

### FR-5: Receipts on gen and view
- gen_command: NuanceReceipts.record() wired after each created artifact (test + subject)
- view_command: NuanceReceipts.record() wired after widget scaffold write
- make_command: skipped (delegates to other commands, no direct file writes)

### Regression fix
- Updated gen_command_ffi_835_test, gen_command_platform_test, batch_gen_test to pass --json

### Full suite
- `dart test test/plugins/tdd/ --exclude-tags slow` → 1091 passed, 0 failed
- `dart analyze lib/ test/` → No issues found
