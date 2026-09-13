# TDD Test List — Spec 1388

Red pre-fix: U1–U3 red — the traces migration reuses (`verdict=reused`)
the stale guard-only pair, no fingerprint machinery exists.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| U1 | Signature-row traces migration → verdict=regenerated, declared assertion, no guard-only marker | FR-2 / AS-1 / SC-001 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U2 | No-signature-row traces migration → verdict=regenerated despite identical bytes; next gen reused | FR-2 / AS-2 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U3 | Drift + progressed subject → refused with --> fix: zfa tdd reset <feature> | FR-3 / AS-3 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U4 | Fingerprint service + record field round-trip (JSON absent → null → preserved through copies) | FR-1 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U5 | Drift fires once per change (refreshed fingerprint reuses) | FR-2 / AS-4 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |
| U6 | Unchanged routing + legacy records keep reuse | FR-4 / FR-5 / AS-5 | test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart |

## Red protocol

```
dart test test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart
```
