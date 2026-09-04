## Summary

Adds the `--json` verdict envelope (`verdict.v1` schema) to all 15 leaf TDD plugin commands and wires `NuanceReceipts` into `gen` and `view` so every generated file gets a #807 provenance receipt.

**VISION §3** (manifest is a treaty), **§4** (errors are an API), **§5** (`--json` everywhere).

## Changes

| File | Change |
|------|--------|
| `lib/src/plugins/tdd/models/verdict_envelope.dart` | **added** — `VerdictEnvelope` model with stable `verdict.v1` schema |
| `lib/src/plugins/tdd/commands/gen_command.dart` | `--json` flag; `_printBatchVerdict` and `_printVerdict` gated on `_jsonMode`; receipts wired after each artifact write |
| `lib/src/plugins/tdd/commands/reset_command.dart` | `--json` flag; `_printVerdict` gated on `_jsonMode` |
| `lib/src/plugins/tdd/commands/view_command.dart` | `--json` flag; receipts wired after widget scaffold write |
| 12 other leaf commands | `--json` flag registered (run, plan, make, realize, verify, verify-red, init, compose, refactor, wire, fake, func) |
| 3 test files | Updated to pass `--json` where tests assert on JSON output |

**Breaking change**: `gen` and `reset` no longer emit JSON unconditionally — JSON is gated on `--json`. This aligns every command to the same contract.

## Tests

- **6** unit tests for `VerdictEnvelope` model (schema, encoding, enum preservation)
- **15** unit tests confirming `--json` flag registration on every leaf command
- **1091** TDD plugin tests pass (0 failures)
- `dart analyze lib/ test/` → 0 issues

## Verification

- Text fallback works: `reset` without `--json` emits `reset: feature=... verdict=...`
- All gen/reset JSON gated: `_jsonMode` controls output format
- Receipts wired: gen and view record NuanceReceipts after file creation

## Residual

- `corpus_*` and `referee` subcommands not yet wired (follow-up)
- 13 remaining commands register `--json` but their `run()` methods don't emit the envelope yet (follow-up)

Assessment: `.specify/bugs/tdd-plugin-json-verdict-receipts-finder-kind/assessment.md`

Closes #994
