# Implementation Plan: shadcn Plugin — UI Vocabulary Authority

**Branch**: `024-shadcn-plugin-ui-vocabulary` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/024-shadcn-plugin-ui-vocabulary/spec.md`

## Summary

Makes the shadcn plugin the UI vocabulary authority (issue #391): a
versioned, diff-stable JSON Schema of the full built-in component
vocabulary exportable via `zfa ui schema`; project-specific composite
components scaffolded as first-class vocabulary entries via
`zfa make <Name> --ui` (node entity + renderer extension + schema
registration); payload validation with precise per-category diagnostics via
`zfa ui validate <file>`; and a macOS-gated preview harness via
`zfa ui preview <file>`.

The repo already has the surrounding machinery: the agent-side
`lib/src/agent/ui_render/` (UiNode model, `UiVocabularySchema` with node
types/style tokens/node cap, `ui.render` tool), the shadcn plugin
(`lib/src/plugins/shadcn/` — widget generator + capability-bearing plugin),
the plugin capability system (`ZuraffaCapability` with JSON-Schema
input/output, MCP-discoverable), and the `zfa make` plugin pipeline. This
feature adds the missing authority layer: a Node Registry (built-ins +
project composites), a schema exporter, a payload validator, a composite
scaffolder, and the `zfa ui` command family.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`); toolchain Dart
3.13.2. Pure Dart under `lib/` — the preview harness ENTRYPOINT it
generates targets the user's Flutter project, but zuraffa itself never
imports Flutter.

**Primary Dependencies**: zero new packages (`dart:convert` for JSON,
`dart:io` for files, `args` for commands).

**Vocabulary source of truth** (Assumption: the flutter-shadcn-ui fork
provides the UINode system): the plugin's built-in registry mirrors the
fork's component set — `container`, `card`, `text`, `heading`, `button`,
`input`, `textarea`, `checkbox`, `switch`, `select`, `option`, `image`,
`avatar`, `badge`, `list`, `row`, `column`, `divider`, `progress`,
`slider`, `tooltip`, `alert`, `label`, `root` — each with props (typed,
enum-valued where applicable), children constraints (min/max/allowed
child types), and a category. Structural rules: `maxDepth: 12`,
`maxNodes: 256`. Style tokens: `primary`, `secondary`, `tertiary`,
`success`, `warning`, `danger`, `neutral`, `muted`, `accent`. Action-ID
grammar: `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$` (dotted lowercase
identifiers).

**Composite registration**: `zfa make <Name> --ui` writes three artifacts
into the target project — the node entity
(`lib/src/ui/nodes/<name>_node.dart`), the renderer extension
(`lib/src/ui/renderers/<name>_renderer.dart`), and the schema registration
(`.zfa/ui/components/<name>.json`). `NodeRegistry.load(projectRoot)` merges
built-ins with every `.zfa/ui/components/*.json` registration, so the next
`zfa ui schema` export includes composites as first-class entries.

**Diff-stability**: the exporter emits sorted keys with deterministic
iteration order and NO timestamps — two consecutive exports with no
vocabulary changes are byte-identical (spec US-1 scenario 2).

**Schema shape** (self-contained component definitions + tool consumption):
the export is a JSON object with `schemaVersion`, `components` (each a
self-contained JSON-Schema object describing props/children of that node
type), `structuralRules` (tree caps), `styleTokens` (enum),
`actionIdGrammar` (pattern + description), and `nestingRules` (per-parent
allowed child types). SC-004: `UiRenderInputSchema.fromExport(export)`
derives the `ui.render` tool's input schema for the `tree` parameter
directly from the export artifact — no manual mapping.

**Payload shape** (consistent with the agent `UiNode`): a payload file is
`{"tree": <node>}` (optionally `"schemaVersion": "1.0.0"` as a pin) or a
bare `<node>`; a node is `{"type": ..., "props"?: {...}, "children"?:
[...], "styleToken"?: ..., "actionId"?: ...}`.

**Validation categories** (FR-003 / SC-003 — zero false negatives):
`unknownNode` (name + tree path), `badToken` (offending token + allowed
set), `rawColor` (raw `#hex`/`rgb()`/`hsl()`/`Colors.x` values in props or
styleToken + token suggestion), `depthCap` (path at the violation),
`countCap` (actual vs cap), `invalidAction` (offender + grammar),
`invalidNesting` (parent/child + constraint), plus `parseError` (invalid
JSON with path/line) and `pinMismatch` (version warning).

**Preview** (FR-004): validate first (errors → no render, exit 1); then
platform gate — non-macOS fails with a platform-not-supported message
(exit 1); on macOS the command writes a preview harness entrypoint
(`<root>/.zfa/ui/preview/main_preview.dart` — a Flutter `main()` that
loads the payload and walks the tree through registered renderers) and
spawns `flutter run -d macos -t <entrypoint>`. The harness-entrypoint
GENERATION is pure and unit-tested; the spawn is platform-gated.

**Version pinning** (FR-005): exports carry a semver `schemaVersion`;
`zfa ui schema --expect-version X` fails on mismatch (CI pin check);
`zfa ui validate` reports a `pinMismatch` warning when the payload
declares a different version than the registry's.

**`zfa make <Name> --ui`** (FR-002): an early intercept in
`MakeCommand.run()` (before entity checks — composites are UI nodes, not
entities). Reserved built-in names are rejected with the reserved list
(FR-007); an existing registration or renderer for the name is a conflict
rejected at scaffold time (Edge Cases) unless `--force`.

**MCP capability** (FR-006): `UiVocabularyExportCapability` added to
`ShadcnPlugin.capabilities` — exposes `export` (returns the schema JSON)
with JSON-Schema input/output, making the vocabulary MCP-discoverable via
the existing capability system.

**Command wiring**: a new top-level `zfa ui` command
(`lib/src/commands/ui_command.dart`) with `schema` / `validate` / `preview`
subcommands, registered in `CliRunner._addCoreCommands()`. Each checks
plugin availability (registry lookup, injectable for tests — FR-008 "shadcn
plugin not found" edge) and takes `--project-root` (defaults to cwd) so
tests can point at temp projects.

**Testing**: `package:test`, fast tier, temp-project fixtures, no network.
macOS-only behavior tested via platform-override injection; the Linux CI
path asserts the platform guard.

## Constitution Check

1. **Library-First**: registry/exporter/validator/scaffolder are libraries
   under `lib/src/plugins/shadcn/vocabulary/`, exported via
   `lib/zuraffa.dart`; commands are thin wrappers.
2. **CLI Interface**: `zfa ui schema|validate|preview` + `zfa make --ui`.
3. **Test-First (NON-NEGOTIABLE)**: every behavior in `tdd/test-list.md`
   has a failing test first; red evidence under `tdd/red/`.
4. **Integration Testing**: composite e2e — scaffold → export includes it
   → payload referencing it validates; schema consumed as-is by the
   `ui.render` input schema adapter.
5. **Simplicity**: zero new dependencies; hand-rolled deterministic JSON
   emission.

## Project Structure

```text
lib/src/plugins/shadcn/
├── vocabulary/
│   ├── ui_node_registry.dart        (NEW — built-in definitions + composite loading)
│   ├── vocabulary_schema_exporter.dart (NEW — versioned diff-stable export + UiRenderInputSchema adapter)
│   ├── payload_validator.dart       (NEW — per-category diagnostics)
│   └── composite_scaffolder.dart    (NEW — node entity + renderer + registration)
└── capabilities/
    └── ui_vocabulary_export_capability.dart (NEW — MCP-discoverable export)

lib/src/commands/ui_command.dart     (NEW — zfa ui schema|validate|preview)
lib/src/commands/make_command.dart   (EXTENDED — --ui intercept)
lib/src/cli/cli_runner.dart          (EXTENDED — register UiCommand)
lib/zuraffa.dart                     (EXTENDED — vocabulary exports)
```

```text
test/plugins/shadcn/
├── ui_node_registry_test.dart       (NEW)
├── vocabulary_schema_exporter_test.dart (NEW)
├── payload_validator_test.dart      (NEW)
├── composite_scaffolder_test.dart   (NEW)
└── ui_command_test.dart             (NEW — CLI wiring incl. error paths)
```

## Goals & Strategy

### Primary goal

`zfa ui schema` exports the full versioned vocabulary (diff-stable);
`zfa make <Name> --ui` yields a composite that appears in the export and
validates in payloads; `zfa ui validate` catches every error category with
actionable diagnostics; `zfa ui preview` renders on macOS and fails
gracefully elsewhere; the export is consumable as-is by `ui.render`.

### Non-goals

- The Flutter-side renderer implementations themselves (live in
  zuraffa_flutter / the fork).
- Actually launching a macOS window in CI (platform-gated spawn; harness
  generation is what is tested).
- Agent-side vocabulary narrowing semantics (spec 023, untouched).

### Strategy (MVP-first)

1. **P1**: registry + exporter (diff-stable, versioned) + `zfa ui schema`.
2. **P1**: composite scaffolder + `zfa make --ui` + composite-in-export.
3. **P2**: payload validator (all categories) + `zfa ui validate`.
4. **P2**: preview command (validation gate + platform gate + harness
   generation) + `zfa ui preview`.
5. **P2**: version pin checks; **P3**: MCP capability; command error paths.

## Risks

- **Built-in vocabulary fidelity to the fork** — the fork lives outside
  this repo; the registry's built-in set is the plugin's authoritative
  mirror, shaped after the shadcn/ui component taxonomy. Versioned, so
  drift is a visible major bump.
- **Preview on non-macOS dev machines** — the platform guard is the
  documented v1 behavior (spec Assumption: macOS first).

## Deferred / Future Work

- Windows/Linux preview harnesses.
- Per-project token overrides in `.zfa.json` (v1 exports the plugin's
  canonical token set).
- Composite prop inference from existing entity fields.
