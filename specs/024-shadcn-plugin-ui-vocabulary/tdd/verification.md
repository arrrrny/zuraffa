# TDD Verification — shadcn Plugin — UI Vocabulary Authority

**Spec**: `specs/024-shadcn-plugin-ui-vocabulary/spec.md`
**Branch**: `024-shadcn-plugin-ui-vocabulary`
**Date**: 2026-08-29

## Summary

All 24 behaviors from `tdd/test-list.md` are GREEN. `zfa ui schema`
exports the full built-in vocabulary (24 components) as a versioned
(`schemaVersion: 1.0.0`), diff-stable JSON Schema — per-component
self-contained definitions (typed props, enums, defaults, children
constraints), structural rules (`maxDepth`/`maxNodes`), style-token enum,
action-ID grammar, and nesting rules; `zfa make <Name> --ui` scaffolds a
composite (node entity + renderer extension + `.zfa/ui/components/*.json`
registration) that loads back into the registry as a first-class entry,
appears in the next export, and validates in payloads; `zfa ui validate`
catches every error category (unknown node, bad token, raw color, depth
cap, count cap, invalid action, invalid nesting) with precise, actionable
diagnostics — all violations reported in a single pass; `zfa ui preview`
validates first, platform-gates (macOS v1), and generates a pure,
unit-tested harness entrypoint; the export is consumed as-is by the
agent plugin's `ui.render` tool input schema via
`UiRenderInputSchema.fromExport` (no manual transformation); the export
is registered as an MCP-discoverable `UiVocabularyExportCapability` on
`ShadcnPlugin`.

## `dart analyze` (whole project)

```
$ dart analyze
88 issues found. (0 errors, 4 warnings, 84 infos)
```

All 88 issues are pre-existing on `master` (unused elements/imports and
lint hints in files this feature does not touch — identical count to the
037 verification baseline). **Zero errors, zero warnings from any file
added or modified by this feature.** Scoped run:

```
$ dart analyze lib/src/plugins/shadcn/vocabulary \
    lib/src/plugins/shadcn/capabilities \
    lib/src/commands/ui_command.dart test/plugins/shadcn
No issues found!
```

## `dart test` (full fast tier, ACTUAL counts)

The suite was executed per-directory batches (the runner's kernel cache
exceeds the sandbox disk when the whole suite runs in one process);
`/tmp/dart_test.kernel.*` cleaned between batches. Every directory under
`test/` was covered (`test/fixtures` contains no `_test.dart` files;
`test/benchmark` is subject to the default tag filter per
`dart_test.yaml`). Note: master moved after this branch's work started
(037 merged as `b3926c93`); the branch was rebased onto fresh master
before this verification run, so the counts below include master's
graphql/tdd-plugin/state-widget suites.

| Scope | Result |
|---|---|
| `test/core` | 572 passed, 1 skipped (pre-existing skip) |
| `test/config test/utils test/helpers test/scripts test/property` | 83 passed |
| `test/cli` | 139 passed |
| `test/dda test/domain test/session test/share test/secure_storage` | 89 passed |
| `test/migration test/i18n test/logging test/device test/app_update test/biometrics test/clipboard test/benchmark` | 62 passed |
| `test/graphql test/commands` | 427 passed |
| `test/agent test/state test/mcp test/integration` | 314 passed |
| `test/plugins/shadcn test/plugins/benchmark test/plugins/xray` | 287 passed |
| `test/plugins/tui test/plugins/mcp` | 183 passed |
| `test/plugins/tdd test/plugins/route test/plugins/usecase test/plugins/sync test/plugins/mock test/plugins/repository test/plugins/provider` | 157 passed |
| `test/plugins/api test/plugins/app_shell test/plugins/datasource test/plugins/di test/plugins/gym test/plugins/method_append test/plugins/module test/plugins/service test/plugins/sqlite test/plugins/state test/plugins/strategy` | 183 passed |
| `test/regression` | 78 passed |
| **Total** | **2574 passed, 1 skipped, 0 failed** |

Of the 2574, **51 are new tests authored for this spec** (9 registry,
6 exporter, 7 scaffolder, 15 validator, 14 command/capability) — the rest
are the pre-existing suite, all still green (no regressions; the
pre-existing `shadcn_plugin_test.dart` passes unmodified alongside the
new vocabulary tests).

## Spec SC mapping (all SC-001..004 proven)

### SC-001 — `zfa ui schema` output validates the full built-in vocabulary and is diff-stable

**PROVEN** by `test/plugins/shadcn/ui_node_registry_test.dart` —
"covers the full built-in component set" (24 built-ins: root, container,
card, text, heading, button, input, textarea, checkbox, switch, select,
option, image, avatar, badge, list, row, column, divider, progress,
slider, tooltip, alert, label) plus
`test/plugins/shadcn/vocabulary_schema_exporter_test.dart` —
"diff-stable: consecutive exports are byte-identical (SC-001)" and
`test/plugins/shadcn/ui_command_test.dart` — "diff-stable across two CLI
runs (SC-001)" (end-to-end through `CliRunner.runCapturing`, two
consecutive `zfa ui schema` runs produce byte-identical artifacts).

### SC-002 — `zfa make <Name> --ui` generates a composite usable, validatable, and renderable end-to-end

**PROVEN** by `test/plugins/shadcn/composite_scaffolder_test.dart` —
"scaffold writes node entity, renderer extension and registration",
"scaffolded composite is a first-class vocabulary entry (SC-002)"
(registration JSON parses back into the registry AND the composite
appears in the export), "payload referencing the composite validates
(US-2 scenario 3)", plus `test/plugins/shadcn/ui_command_test.dart` —
"`zfa make <Name> --ui` (FR-002) scaffolds a composite without requiring
an entity" (full e2e through MakeCommand on a temp project root) and
"zfa ui preview macOS path generates the harness entrypoint" (render
path — the entrypoint the preview spawns is generated and asserted).

### SC-003 — `zfa ui validate` catches all five categories with zero false negatives

**PROVEN** by `test/plugins/shadcn/payload_validator_test.dart` —
individual category tests (unknown node w/ name + tree position; bad
token w/ offender + allowed set; raw color in styleToken AND in prop
values w/ token suggestion; depth cap w/ deep path; count cap w/ actual
vs cap; invalid action w/ grammar) plus "all violations reported in one
pass (SC-003, zero false negatives)" — a curated corpus payload carrying
every violation category yields ALL diagnostics in a single validation
pass; end-to-end exit codes asserted in
`test/plugins/shadcn/ui_command_test.dart` — "valid payload exits 0 with
clean report" / "invalid payload exits 1 with diagnostics".

### SC-004 — exported schema consumed as-is by the agent plugin's `ui.render` tool

**PROVEN** by `test/plugins/shadcn/vocabulary_schema_exporter_test.dart`
— "ui.render tree input schema derives from the export as-is"
(`UiRenderInputSchema.fromExport(export)` builds the tool's `tree`
parameter schema purely from the export artifact; `validateTree` accepts
a valid tree and rejects unknown node types — no manual mapping) and
`test/plugins/shadcn/ui_command_test.dart` — "execute returns the
exported schema with schemaVersion" (the MCP capability serves the same
artifact, FR-006).

## FR coverage

- **FR-001** — exporter tests (shape, self-contained components) + `zfa ui schema` CLI tests
- **FR-002** — scaffolder tests (three artifacts, first-class entry) + `make --ui` e2e
- **FR-003** — validator tests (all categories, one-pass aggregation, parse errors)
- **FR-004** — preview tests (validate-first, platform gate, harness generation)
- **FR-005** — version tests (semver field, bump changes bytes, `--expect-version` pin, `pinMismatch` warning)
- **FR-006** — capability tests (plugin exposes capability; execute returns schema w/ schemaVersion)
- **FR-007** — reserved-names tests (registry + scaffolder, reserved list in the rejection)
- **FR-008** — error-path tests (plugin missing, file not found, invalid JSON, non-macOS platform)
