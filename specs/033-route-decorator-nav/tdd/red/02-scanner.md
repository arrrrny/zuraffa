# Red Evidence — @Route annotation scanner

**Test file**: `test/routing/route_annotation_scanner_test.dart`
**Behaviors**: B04 — named-arg decoding; B05 — @Route.redirect /
@Route.middleware forms; B06 — non-View detection; B07 — View detection +
shell child param
**Spec**: FR-001, FR-006, US-1, US-4

## First-run output (before implementation)

```
$ dart test test/routing/route_annotation_scanner_test.dart
  test/routing/route_annotation_scanner_test.dart:4:8: Error: Error when
  reading 'lib/src/routing/route_annotation_scanner.dart': No such file or
  directory
  test/routing/route_annotation_scanner_test.dart:41:26: Error: Method not
  found: 'RouteAnnotationScanner'.
  ... (13 occurrences)
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no annotation scanner existed anywhere in lib/.
