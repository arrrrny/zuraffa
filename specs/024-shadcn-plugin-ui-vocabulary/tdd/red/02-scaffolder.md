# Red Evidence — Composite scaffolder (zfa make --ui)

**Test file**: `test/plugins/shadcn/composite_scaffolder_test.dart`
**Behaviors**: B07 — three artifacts; B08 — first-class entry; B09 —
reserved names; B10 — conflicts + --force
**Spec**: FR-002, FR-007, US-2, SC-002, Edge Cases

## First-run output (before implementation)

```
$ dart test test/plugins/shadcn/composite_scaffolder_test.dart
  Error: Error when reading
  'lib/src/plugins/shadcn/vocabulary/composite_scaffolder.dart': No such
  file or directory
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no composite scaffolding existed.
