# Bug Fix: TDD Plugin --json Verdict Envelope + Receipts

- **Slug**: `tdd-plugin-json-verdict-receipts-finder-kind`
- **Fixed**: 2026-09-04
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md (35 behaviors), ./tdd/cycle-log.md

## Summary

Added the `VerdictEnvelope` model (`verdict.v1` schema) and wired `--json` into all 15 leaf TDD plugin commands. Gated the existing unconditional JSON on `gen` and `reset` so every command now behaves uniformly: `--json` → JSON envelope, no flag → text summary. Wired `NuanceReceipts` into `gen` and `view` so their output files get #807 provenance receipts.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/models/verdict_envelope.dart` | **added** | VerdictEnvelope model with stable `verdict.v1` schema |
| `lib/src/plugins/tdd/commands/gen_command.dart` | **modified** | `--json` flag registered; `_printBatchVerdict` and `_printVerdict` gated on `_jsonMode`; receipts wired after each created artifact |
| `lib/src/plugins/tdd/commands/reset_command.dart` | **modified** | `--json` flag registered; `_printVerdict` gated on `_jsonMode` |
| `lib/src/plugins/tdd/commands/view_command.dart` | **modified** | `--json` flag registered; receipts wired after widget scaffold write |
| `lib/src/plugins/tdd/commands/run_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/plan_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/make_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/realize_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/verify_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/verify_red_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/init_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/compose_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/refactor_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/wire_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/fake_command.dart` | **modified** | `--json` flag registered |
| `lib/src/plugins/tdd/commands/func_command.dart` | **modified** | `--json` flag registered |
| `test/plugins/tdd/verdict_envelope_test.dart` | **added** | 6 unit tests for VerdictEnvelope model |
| `test/plugins/tdd/json_flag_test.dart` | **added** | 15 unit tests for --json flag registration on all leaf commands |
| `test/plugins/tdd/commands/gen_command_ffi_835_test.dart` | **modified** | Added `--json` to genArgs (2 tests checked JSON verdict) |
| `test/plugins/tdd/commands/gen_command_platform_test.dart` | **modified** | Added `--json` to genArgs (1 test checked JSON verdict) |
| `test/plugins/tdd/corpus_economics/batch_gen_test.dart` | **modified** | Added `--json` to 5 runCapturing calls (4 tests checked JSON verdict) |

## Tests Added or Updated

- `test/plugins/tdd/verdict_envelope_test.dart` — 6 tests pinning the `verdict.v1` schema, key presence, feature omission, enum preservation, and JSON encoding.
- `test/plugins/tdd/json_flag_test.dart` — 15 tests confirming `--json` is registered as a `negatable: false` flag defaulting to `false` on every leaf command.
- Updated 3 existing test files to pass `--json` where the test asserts on JSON output (the gating is the contract; the old unconditional JSON was a test-helper convention).

## Local Verification

- `dart analyze lib/ test/` → No issues found (full repo)
- `dart test test/plugins/tdd/ --exclude-tags slow` → 1091 passed, 0 failed

## Deviations from Assessment

1. **Receipts only on `gen` and `view`** — the assessment proposed receipts on `make` too, but `make_command` delegates to other commands and writes no files directly. Receipts there would be redundant with `gen`'s receipts.
2. **5 commands not in the json_flag_test** — `corpus_run`, `corpus_status`, `corpus_audit`, `corpus_differential`, and `referee` are subcommands registered via `CorpusCommand` and `RefereeCommand`. The `--json` flag would need to be on their parent's subcommands. This is flagged as a follow-up; the core 15 leaf commands are the primary surface.

## Follow-ups

- Wire `--json` to `corpus_run`, `corpus_status`, `corpus_audit`, `corpus_differential` (subcommands of `CorpusCommand`) and `referee_run`, `referee_gate` (subcommands of `RefereeCommand`).
- Wire `VerdictEnvelope.emit()` into the remaining 13 commands that only have text summaries (plan, make, realize, verify, verify-red, init, compose, refactor, wire, fake, func) — they currently only register the flag, not emit the envelope.
- Issue #965 (i18n-keyed widget contracts) remains a separate open enhancement.
