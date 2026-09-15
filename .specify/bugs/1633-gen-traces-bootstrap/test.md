# Test — 1633 (plan+gen bootstrap arms the fingerprint)

## Red (before the rewrite, master @ 0c50b959)

The B1 test was `skip:`-ped (skipped tests never ran):

```bash
dart test test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart
# 0 +0: All tests skipped.
```

Un-skipped as originally written, B1 fails at the routing assertion —
gen keeps reuse for the hand-seeded legacy record (correct #1388/U6
behavior), so the regenerated routing never lands:

```dart
expect(testFile, contains('adaptive_layouts')); // FAILS — guard-only stub
```

## Green (after the rewrite)

```bash
dart test test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart
# 2/2 pass — B1 + B2
```

- B1: seeded record carries a 64-hex `gen_fingerprint`; after the cell
  mutation the re-gen reports `verdict=regenerated` + the #1388 drift
  note; the regenerated test's group is
  `U1 (FR-007, adaptive_layouts)`; the stored fingerprint refreshes.
- B2: unchanged routing reuses byte-identical with no drift note.

Sibling suite untouched and still green:

```bash
dart test test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart
```
