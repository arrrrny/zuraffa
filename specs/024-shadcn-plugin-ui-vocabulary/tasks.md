# Tasks: shadcn Plugin — UI Vocabulary Authority

**Input**: Design documents from `specs/024-shadcn-plugin-ui-vocabulary/`

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: Tasks marked with `[T]` are behavior-driving test tasks written FIRST
(TDD red), then made green by their pairing implementation task.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1=Schema export (P1), US2=Composite codegen (P1),
  US3=Validation (P2), US4=Preview (P2), US5=Versioning (P2)

## Phase 1: Node registry + schema export (US1)

- [x] T01 [T] US1 RED: `test/plugins/shadcn/ui_node_registry_test.dart` —
      built-in registry covers the full component set (root, container,
      card, text, heading, button, input, textarea, checkbox, switch,
      select, option, image, avatar, badge, list, row, column, divider,
      progress, slider, tooltip, alert, label); definitions carry props
      with types/enums/defaults, children constraints; `reservedNames`
      equals the built-in key set; composites load from
      `.zfa/ui/components/*.json` and merge as first-class entries;
      missing directory → empty composite set; malformed registration →
      clear error.
- [x] T02 US1 GREEN: Implement
      `lib/src/plugins/shadcn/vocabulary/ui_node_registry.dart`.
- [x] T03 [T] US1 RED: `test/plugins/shadcn/vocabulary_schema_exporter_test.dart`
      — export contains `schemaVersion` (semver), `components` with
      self-contained per-component definitions (props/enums/children),
      `structuralRules` (maxDepth/maxNodes), `styleTokens` enum,
      `actionIdGrammar` pattern, `nestingRules`; two exports are
      byte-identical (diff-stable); higher schemaVersion changes bytes;
      empty registry → minimal valid schema with empty components;
      composite entries appear alongside built-ins.
- [x] T04 US1 GREEN: Implement
      `lib/src/plugins/shadcn/vocabulary/vocabulary_schema_exporter.dart`.

## Phase 2: Composite codegen (US2)

- [x] T05 [T] US2 RED: `test/plugins/shadcn/composite_scaffolder_test.dart`
      — scaffold writes node entity, renderer extension, and schema
      registration; registration JSON parses back into the registry;
      scaffolded composite appears in the export; reserved built-in names
      rejected with the reserved list; existing registration conflict
      rejected (renderer conflict edge case); `--force` overwrites; invalid
      names (non-PascalCase) rejected.
- [x] T06 US2 GREEN: Implement
      `lib/src/plugins/shadcn/vocabulary/composite_scaffolder.dart`.
- [x] T07 [T] US2 RED: `zfa make <Name> --ui` intercept — covered in
      `test/plugins/shadcn/ui_command_test.dart` (e2e via MakeCommand with
      a temp project root): `--ui` generates the three artifacts without
      requiring an entity; running without `--ui` is unaffected.

## Phase 3: Validation (US3)

- [x] T08 [T] US3 RED: `test/plugins/shadcn/payload_validator_test.dart` —
      valid payload passes; unknownNode names the node + tree path;
      badToken reports offending token + allowed set; rawColor detects
      `#hex`/`rgb()`/`hsl()`/`Colors.x` in props and styleToken and
      suggests token format; depthCap pinpoints the deep path; countCap
      reports actual vs cap; invalidAction reports the offender + grammar;
      invalidNesting pinpoints parent/child + constraint; invalid JSON →
      parse error; ALL violations reported in one pass (zero false
      negatives on the curated corpus); pin mismatch warning when payload
      schemaVersion differs.
- [x] T09 US3 GREEN: Implement
      `lib/src/plugins/shadcn/vocabulary/payload_validator.dart`.

## Phase 4: CLI commands (US1/US3/US4/US5)

- [x] T10 [T] US1 RED: `test/plugins/shadcn/ui_command_test.dart` —
      `zfa ui schema` (via CliRunner.runCapturing) writes/prints the
      schema; `--out <file>` writes the artifact; `--expect-version`
      mismatch fails; plugin-missing produces "shadcn plugin not found —
      install it first"; `zfa ui validate <file>` exit 0 + clean report on
      valid payload, exit 1 + diagnostics on invalid; file-not-found and
      invalid-JSON errors actionable; `zfa ui preview <file>` validates
      first (invalid → errors, no render), non-macOS → platform error
      message; harness entrypoint generation is pure and testable
      (macOS-path unit test with platform override).
- [x] T11 US1 GREEN: Implement `lib/src/commands/ui_command.dart`
      (schema/validate/preview subcommands); register in `CliRunner`;
      wire `--ui` intercept into `MakeCommand`.

## Phase 5: MCP capability + exports (US1/FR-006)

- [x] T12 [T] US1 RED: capability test — `ShadcnPlugin().capabilities`
      contains `UiVocabularyExportCapability`; `execute({})` returns the
      exported schema JSON with schemaVersion; input/output JSON schemas
      present.
- [x] T13 US1 GREEN: Implement
      `lib/src/plugins/shadcn/capabilities/ui_vocabulary_export_capability.dart`;
      add to `ShadcnPlugin.capabilities`; barrel exports for the
      vocabulary libraries.

## Phase 6: SC-004 integration + verify

- [x] T14 [T] US1 RED: SC-004 integration test — exported schema →
      `UiRenderInputSchema.fromExport(export)` → tree parameter schema
      accepts a valid tree and rejects unknown node types, derived purely
      from the export artifact.
- [x] T15 GREEN: implement the adapter in the exporter library.
- [x] T16 `dart analyze` — zero errors, zero new warnings.
- [x] T17 Full `dart test` — ACTUAL counts; pre-existing failures flagged.
- [x] T18 Red evidence for every behavior under `tdd/red/`; author
      `tdd/verification.md` mapping SC-001..004.
