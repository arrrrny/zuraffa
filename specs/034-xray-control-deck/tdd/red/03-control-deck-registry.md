# Red Evidence — XRayControlDeck runtime registry + Stream + release guard

**Test file**: `test/plugins/xray/xray_control_deck_test.dart`
**Behaviors**: B06 (empty start), B07 (register), B08 (dedup by name+payload),
B09 (clear), B10 (find), B11 (inject), B12 (changes stream), B13/B14/B15/B16
(release-mode guards)
**Spec**: FR-005, FR-006, FR-007, FR-008, SC-001, SC-003

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_control_deck_test.dart

Failed to load "test/plugins/xray/xray_control_deck_test.dart":
  Error: Target of URI doesn't exist: 'package:zuraffa/src/plugins/xray/xray_control_deck.dart'.
  Error: Method not found: 'XRayControlDeck'.
```

**Status**: RED ✓ — 19 test cases authored before
`lib/src/plugins/xray/xray_control_deck.dart` existed.

## Resolution

Implementation: `lib/src/plugins/xray/xray_control_deck.dart` —
mutable registry keyed by `"$name\x00$payload"` for O(1) dedup and lookup;
broadcast `Stream<List<XRayMockEntry>>` for the Flutter UI;
`_isReleaseMode` guard on every public method.

Subsequent run (green):
```
00:04 +39: All tests passed!  (cumulative across type + entry + deck)
```
