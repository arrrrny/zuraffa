# Red Evidence — Release-mode strip regression for X-Ray Control Deck

**Test file**: `test/regression/issue_185_xray_deck_release_strip_test.dart`
**Behaviors**: B13 (release registerEntries no-op), B14 (release inject null),
B15 (release find null), B16 (release toJson reports release_mode)
**Spec**: FR-007, SC-003

## First-run output (before implementation)

```
$ dart test test/regression/issue_185_xray_deck_release_strip_test.dart

Failed to load "test/regression/issue_185_xray_deck_release_strip_test.dart":
  Error: Method not found: 'kXrayReleaseMode' (in lib/src/core/xray_config.dart).
  Error: Method not found: 'XRayControlDeck' (in lib/src/plugins/xray/xray_control_deck.dart).
```

**Status**: RED ✓

## Resolution

- Added `kXrayReleaseMode` and `shouldXRayBeActiveInCurrentBuild()` to
  `lib/src/core/xray_config.dart` (the pure-Dart equivalent of Flutter's
  `kReleaseMode` / `kDebugMode`).
- Implemented `XRayControlDeck` with `_isReleaseMode` guard on every
  public method.

Subsequent run (green):
```
00:04 +58: All tests passed!  (cumulative across all 5 spec 034 test files)
```

## Note on parallel PRs

This branch (034-xray-control-deck) is based on master, NOT on the
036-xray-visual-overlay branch. Both branches add `kXrayReleaseMode` to
`lib/src/core/xray_config.dart` independently. When both PRs are merged,
the line additions will trivially resolve (identical content) or may
require a one-line merge resolution in `xray_config.dart`.
