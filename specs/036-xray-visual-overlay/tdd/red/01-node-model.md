# Red Evidence — XRayNode data model + JSON round-trip

**Test file**: `test/plugins/xray/xray_node_test.dart`
**Behavior**: B07 — XRayNode immutable data + JSON round-trip
**Spec**: FR-002, FR-003 (registered node data shape)

## First-run output (before implementation)

```
$ dart test test/plugins/xray/xray_node_test.dart --reporter compact

00:01 +0 -1: loading test/plugins/xray/xray_node_test.dart [E]
Failed to load "test/plugins/xray/xray_node_test.dart":
  test/plugins/xray/xray_node_test.dart:11:8: Error: Target of URI doesn't exist.
    import 'package:zuraffa/src/plugins/xray/xray_node.dart';
            ^
  test/plugins/xray/xray_node_test.dart:12:8: Error: Target of URI doesn't exist.
    import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';
            ^
  test/plugins/xray/xray_node_test.dart:18:20: Error: Method not found: 'XRayNode'.
        const node = XRayNode(
                     ^^^^^^^^
  test/plugins/xray/xray_node_test.dart:24:20: Error: Method not found: 'XRayStateSummary'.
            stateSummary: XRayStateSummary(
                          ^^^^^^^^^^^^^^^^^^
```

**Status**: RED ✓ — test authored before `lib/src/plugins/xray/xray_node.dart` and
`lib/src/plugins/xray/xray_state_summary.dart` existed. The compile-error red
phase is acceptable per the constitution's Test-First gate because the test
predates the implementation.

## Resolution

Implementation files created:
- `lib/src/plugins/xray/xray_state_summary.dart`
- `lib/src/plugins/xray/xray_node.dart`

Subsequent run (green):
```
00:01 +7: All tests passed!
```
