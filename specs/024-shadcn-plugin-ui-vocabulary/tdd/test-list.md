# TDD Test List — shadcn Plugin — UI Vocabulary Authority

**Spec**: `specs/024-shadcn-plugin-ui-vocabulary/spec.md`
**Plan**: `specs/024-shadcn-plugin-ui-vocabulary/plan.md`
**Tasks**: `specs/024-shadcn-plugin-ui-vocabulary/tasks.md`

## Behaviors

### B01 — Built-in node registry covers the full vocabulary

- **Spec**: FR-001, US-1 scenario 1, Key Entities (Node Registry)
- **Test**: `test/plugins/shadcn/ui_node_registry_test.dart` — `built-in set`
- **Implementation**: `lib/src/plugins/shadcn/vocabulary/ui_node_registry.dart` — `NodeRegistry.builtIns`

### B02 — Registry loads project composites as first-class entries

- **Spec**: FR-002 scenario 2, Key Entities
- **Test**: same file — `composites load from .zfa/ui/components`
- **Implementation**: `NodeRegistry.load`

### B03 — Export is versioned, complete, and self-contained

- **Spec**: FR-001, FR-005, US-1 scenarios 1/3, US-5 scenario 1
- **Test**: `test/plugins/shadcn/vocabulary_schema_exporter_test.dart` — `export shape`
- **Implementation**: `vocabulary_schema_exporter.dart` — `VocabularySchemaExporter.export`

### B04 — Export is diff-stable

- **Spec**: FR-005, US-1 scenario 2, SC-001
- **Test**: same file — `diff-stable across runs`
- **Implementation**: deterministic sorted-key emission, no timestamps

### B05 — Version bump changes the export (US-5 scenario 2)

- **Spec**: FR-005
- **Test**: same file — `version bump changes bytes`
- **Implementation**: exporter `schemaVersion` parameter

### B06 — Empty registry → minimal valid schema (Edge Cases)

- **Spec**: Edge Cases (empty node registry)
- **Test**: same file — `empty registry minimal schema`
- **Implementation**: exporter

### B07 — Composite scaffold produces node entity + renderer + registration

- **Spec**: FR-002, US-2 scenario 1
- **Test**: `test/plugins/shadcn/composite_scaffolder_test.dart` — `scaffold writes three artifacts`
- **Implementation**: `composite_scaffolder.dart` — `CompositeScaffolder.scaffold`

### B08 — Scaffolded composite is a first-class vocabulary entry

- **Spec**: FR-002 scenarios 2/3, SC-002, US-2
- **Test**: same file — `composite appears in export`, `payload referencing composite validates`
- **Implementation**: scaffolder registration format + registry loading

### B09 — Reserved names rejected with the reserved list (FR-007)

- **Spec**: FR-007, Edge Cases
- **Test**: same file — `reserved name rejection`
- **Implementation**: scaffolder + `NodeRegistry.reservedNames`

### B10 — Existing registration / renderer conflicts rejected at scaffold time

- **Spec**: Edge Cases (renderer conflict)
- **Test**: same file — `conflict rejection`, `--force overwrites`
- **Implementation**: scaffolder

### B11 — Valid payload passes validation

- **Spec**: FR-003, US-3 scenario 1
- **Test**: `test/plugins/shadcn/payload_validator_test.dart` — `valid payload`
- **Implementation**: `payload_validator.dart` — `UiPayloadValidator.validate`

### B12 — unknownNode diagnostic (name + tree position)

- **Spec**: FR-003, US-3 scenario 2
- **Test**: same file — `unknown node`
- **Implementation**: validator tree walk with path tracking

### B13 — badToken diagnostic

- **Spec**: FR-003
- **Test**: same file — `bad token`
- **Implementation**: validator token check

### B14 — rawColor diagnostic with token suggestion

- **Spec**: FR-003, US-3 scenario 4
- **Test**: same file — `raw color`
- **Implementation**: validator raw-color pattern check on props + styleToken

### B15 — depthCap + countCap diagnostics (US-3 scenario 3)

- **Spec**: FR-003, US-3 scenario 3
- **Test**: same file — `depth cap`, `count cap`
- **Implementation**: validator structural walk

### B16 — invalidAction diagnostic with grammar (US-3 scenario 5)

- **Spec**: FR-003, US-3 scenario 5
- **Test**: same file — `invalid action`
- **Implementation**: validator action-ID check

### B17 — invalidNesting diagnostic (parent/child + constraint)

- **Spec**: FR-003, US-3 scenario 3
- **Test**: same file — `invalid nesting`
- **Implementation**: validator children-constraint check

### B18 — All violations in one pass; parse errors actionable; pin mismatch

- **Spec**: FR-003, FR-005, SC-003, Edge Cases (invalid JSON)
- **Test**: same file — `all errors at once`, `invalid JSON`, `pin mismatch warning`
- **Implementation**: validator

### B19 — `zfa ui schema` CLI (write, --out, --expect-version, plugin-missing)

- **Spec**: FR-001, FR-005, FR-008, US-1, US-5 scenario 3, Edge Cases
- **Test**: `test/plugins/shadcn/ui_command_test.dart` — schema command tests
- **Implementation**: `lib/src/commands/ui_command.dart`

### B20 — `zfa ui validate` CLI exit codes + diagnostics

- **Spec**: FR-003, FR-008, US-3
- **Test**: same file — validate command tests
- **Implementation**: ui_command.dart

### B21 — `zfa ui preview` validates first; platform gate; harness generation

- **Spec**: FR-004, FR-008, US-4, Edge Cases (non-macOS)
- **Test**: same file — preview command tests
- **Implementation**: ui_command.dart + harness entrypoint emitter

### B22 — `zfa make <Name> --ui` intercept

- **Spec**: FR-002, SC-002
- **Test**: same file — make --ui e2e
- **Implementation**: `MakeCommand` `--ui` hook

### B23 — MCP capability registration (FR-006)

- **Spec**: FR-006
- **Test**: `test/plugins/shadcn/ui_command_test.dart` — capability group
- **Implementation**: `ui_vocabulary_export_capability.dart` on ShadcnPlugin

### B24 — SC-004: export consumed as-is by ui.render inputSchema

- **Spec**: SC-004, US-1 scenario 4
- **Test**: `test/plugins/shadcn/vocabulary_schema_exporter_test.dart` — `ui.render input schema from export`
- **Implementation**: `UiRenderInputSchema.fromExport`
