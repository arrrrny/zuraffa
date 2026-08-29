# Red Evidence — XRayStateSummary data class + fromPreviews factory

**Test file**: `test/plugins/xray/xray_state_summary_test.dart`
**Behavior**: B09 — XRayStateSummary data class + fromPreviews factory
**Spec**: FR-003 (SignalSlice state summary: data/error/loading)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_state_summary_test.dart --reporter compact

Failed to load "test/plugins/xray/xray_state_summary_test.dart":
  test/plugins/xray/xray_state_summary_test.dart:7:8: Error: Target of URI doesn't exist.
    import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';
            ^
  test/plugins/xray/xray_state_summary_test.dart:12:18: Error: Method not found: 'XRayStateSummary'.
        const s = XRayStateSummary(
```

**Status**: RED ✓ — test authored before
`lib/src/plugins/xray/xray_state_summary.dart` existed.

## Resolution

Implementation: `lib/src/plugins/xray/xray_state_summary.dart`.

Subsequent run (green):
```
00:00 +9: All tests passed!
```
