# Red Evidence — Node registry + schema exporter

**Test files**: `test/plugins/shadcn/ui_node_registry_test.dart`,
`test/plugins/shadcn/vocabulary_schema_exporter_test.dart`
**Behaviors**: B01 — built-in coverage; B02 — composite loading; B03 — export
shape; B04 — diff-stability; B05 — version bump; B06 — empty registry;
B24 — ui.render input schema derivation (SC-004)
**Spec**: FR-001, FR-005, US-1, US-5, SC-001, SC-004

## First-run output (before implementation)

```
$ dart test test/plugins/shadcn/ui_node_registry_test.dart
  Error: Error when reading
  'lib/src/plugins/shadcn/vocabulary/ui_node_registry.dart': No such file or
  directory
  Error: Undefined name 'NodeRegistry'.
00:00 +0 -1: Some tests failed.

$ dart test test/plugins/shadcn/vocabulary_schema_exporter_test.dart
  Error: Error when reading
  'lib/src/plugins/shadcn/vocabulary/ui_node_registry.dart' ...
  Error: Error when reading
  'lib/src/plugins/shadcn/vocabulary/vocabulary_schema_exporter.dart' ...
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — no vocabulary authority module existed in the shadcn
plugin (the agent-side `UiVocabularySchema` has only an allowed-type set,
no per-component definitions, no export).
