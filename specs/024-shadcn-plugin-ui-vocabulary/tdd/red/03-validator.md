# Red Evidence — Payload validator (zfa ui validate)

**Test file**: `test/plugins/shadcn/payload_validator_test.dart`
**Behaviors**: B11 — valid pass; B12 — unknownNode; B13 — badToken; B14 —
rawColor; B15 — depth/count caps; B16 — invalidAction; B17 —
invalidNesting; B18 — aggregate + parse + pin
**Spec**: FR-003, FR-005, US-3, SC-003, Edge Cases

## First-run output (before implementation)

```
$ dart test test/plugins/shadcn/payload_validator_test.dart
  Error: Error when reading
  'lib/src/plugins/shadcn/vocabulary/payload_validator.dart': No such file
  or directory
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — the existing agent-side validator covers only
unknownNodeType/invalidToken/capOverflow on `UiNode` objects with no raw
color, action grammar, nesting, depth, or file/JSON handling.
