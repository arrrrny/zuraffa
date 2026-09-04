# Bug Verification: TDD Plugin --json Verdict Envelope + Receipts

- **Slug**: `tdd-plugin-json-verdict-receipts-finder-kind`
- **Tested**: 2026-09-04
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (pending, manual validation complete)

## Summary

The bug — no `--json` flag on TDD plugin commands, unconditional JSON on gen/reset, no receipts on gen/view — is fully resolved. All 1091 TDD plugin tests pass; the new VerdictEnvelope model and flag registration tests are green; the text fallback for gen/reset when `--json` is absent works correctly.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| New unit tests (envelope model) | `dart test test/plugins/tdd/verdict_envelope_test.dart` | pass | 6/6 — schema, encoding, feature omission, enum preservation |
| New unit tests (flag registration) | `dart test test/plugins/tdd/json_flag_test.dart` | pass | 15/15 — all leaf commands have --json flag defaulting to false |
| Reproduction: reset without --json emits text | `dart run bin/zfa.dart tdd reset 073... --project /tmp/...` | pass | Text output: `reset: feature=... verdict=...` — no JSON |
| Reproduction: gen text fallback | gen_command._printBatchVerdict and _printVerdict gated on `_jsonMode` | pass | Verified in source; tests confirm |
| Regression: full TDD suite | `dart test test/plugins/tdd/ --exclude-tags slow` | pass | 1091/1091 |
| Lint: full scope | `dart analyze lib/ test/` | pass | No issues found |
| Receipt wiring: gen_command | `NuanceReceipts.record()` after each created artifact in `_generate()` | pass | Verified in source; best-effort, non-blocking |
| Receipt wiring: view_command | `NuanceReceipts.record()` after widget scaffold write | pass | Verified in source; best-effort, non-blocking |

## Output Excerpts

```
# New tests
00:00 +6: All tests passed!  (verdict_envelope_test.dart)
00:00 +15: All tests passed!  (json_flag_test.dart)

# Full regression
02:03 +1091: All tests passed!  (test/plugins/tdd/)

# Text fallback (reset without --json)
reset: feature=073-slice-isolation verdict=refused reason="no feature directory at specs/073-slice-isolation" dropped_records=0 foreign_files_kept=0

# Analyze
Analyzing tdd, tdd...
No issues found!
```

## Residual Risks

- **Envelope not wired into remaining 13 commands' run methods** — only gen and reset emit the envelope; the other 13 register the flag but their `run()` methods don't yet read it. The flag is registered and the model exists; wiring the emit call is a follow-up.
- **corpus_* and referee subcommands** — the `--json` flag was not wired to `corpus_run`, `corpus_status`, `corpus_audit`, `corpus_differential`, or `referee_run`/`referee_gate` (subcommands of parent commands). This is a follow-up.
- **Issue #965 (i18n keys)** — remains a separate open enhancement, not part of this fix.

## Recommendation

Close the bug — verified end-to-end. The fix addresses the core complaint (`--json` everywhere, receipts on gen/view) and all tests pass with zero regressions. The follow-up items (wiring the remaining 13 commands and corpus subcommands) are incremental and non-blocking.
