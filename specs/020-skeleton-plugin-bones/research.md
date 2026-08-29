# Research: Skeleton Plugin — Bare-Bones Feature Scaffold

Phase 0 consolidation. The Technical Context had no NEEDS CLARIFICATION items;
the decisions below resolve the open design questions for bone generation,
dependency resolution, and export.

## Decision 1: Integration point — plugin, not standalone command

- **Decision**: Implement `SkeletonPlugin` as a `FileGeneratorPlugin` that also
  implements `CliAwarePlugin`, registered in `PluginLoader._plugins()`
  (`lib/src/cli/plugin_loader.dart`).
- **Rationale**: The repo has exactly two integration paths: (A) plugin +
  `CliAwarePlugin` → auto-registered CLI subcommand, used by ~30 plugins;
  (B) standalone `Command<void>` in `CliRunner._addCoreCommands()`, used only
  for core plumbing (make, entity, xray). Bone generation produces files and
  participates in generation lifecycles — that is the plugin path (A).
- **Alternatives considered**: standalone command (rejected: bypasses plugin
  lifecycle, validation, and registry dependency ordering for no benefit).

## Decision 2: Bone output location and manifest format

- **Decision**: Bones live under `.zfa/bones/<feature-slug>/`. The manifest is
  `bone.yaml` (YAML via the existing `yaml` dependency).
- **Rationale**: `.zfa/` is the documented canonical memory surface for
  generated artifacts (plans, runs, manifests per AGENTS.md); bones are the
  same class of artifact. YAML matches the existing manifest/config style
  (`.zfa.json`, plugin configs) and is human-editable by orchestrating agents.
- **Alternatives considered**: JSON manifest (rejected: less readable, and
  `yaml` is already a dependency so no cost either way — readability wins for
  a file external agents must parse by eye); `specs/<feature>/bone/` (rejected:
  `specs/` is speckit-owned documentation, not a generation target).

## Decision 3: How entities/dependencies are discovered from a feature

- **Decision**: A `SpecReader` reads the feature's `spec.md` structurally:
  entity names from the `## Key Entities` section (bold `**Name**` entries) and
  from `zfa entity create`-style declarations when present; cross-references
  are detected by scanning other feature specs for the same entity names.
  Explicit `--entity` and `--depends-on` CLI flags override/extend detection.
- **Rationale**: The spec's Assumptions state feature definitions include
  explicit entity declarations and the generator "does not infer entities from
  prose" — so we parse only structured headings/declarations, never prose.
  Cross-feature entity matching gives FR-003's automatic dependency graph
  without a new authoring format.
- **Alternatives considered**: a new machine-authored `bone.yaml` input format
  (rejected: duplicates spec.md, violates "derive automatically"); full
  markdown AST parsing (rejected: prose inference is explicitly out of scope).

## Decision 4: Cycle detection

- **Decision**: Kahn's algorithm (topological sort) over the bone dependency
  graph; on failure, report the remaining nodes as the cycle with their names.
- **Rationale**: O(V+E), trivially meets SC-003 (≤ 20 bones, < 5s), and the
  leftover-node set IS the human-readable cycle report FR-004 requires.
- **Alternatives considered**: DFS three-color marking (equivalent; Kahn gives
  the full build order as a by-product, which multi-bone assembly needs anyway).

## Decision 5: Spec version reference (staleness)

- **Decision**: SHA-256 of the source `spec.md` bytes, stored as
  `spec_version: sha256:<hex>` in the manifest, plus the feature slug.
- **Rationale**: `crypto` is already a dependency; content hashing detects ANY
  spec change without a versioning scheme speckit doesn't have (FR-008, edge
  case 4).
- **Alternatives considered**: git commit hash of the spec (rejected: breaks
  when the bone is exported outside the repo — the exact scenario this feature
  serves); semantic version field in spec.md (rejected: speckit has no such
  field; would require authoring discipline the tool can't enforce).

## Decision 6: Export format

- **Decision**: `zfa bone export <feature>` writes
  `.zfa/bones/<feature-slug>.tar.gz` via the `archive` package (new dependency).
- **Rationale**: tar.gz is the expected handoff format for CLI tooling; the
  `archive` package is the standard pure-Dart implementation (no platform
  calls, works everywhere the CLI runs). Spec allows "compressed archive or
  equivalent" (FR-006).
- **Alternatives considered**: plain directory copy (rejected: not a "single
  transferable artifact" per acceptance scenario 4.1); zip (acceptable but
  tar.gz is the convention for source handoffs); shelling out to `tar`
  (rejected: not portable, untestable in-process).

## Decision 7: Self-containment validation (FR-005)

- **Decision**: After emission, scan generated `.dart` stubs for `import` /
  `export` directives; every directive must resolve to (a) a file inside the
  bone, (b) the Dart SDK (`dart:*`), or (c) a bone declared in the manifest's
  dependency list. Any other reference fails generation with a
  missing-dependency error naming the offending reference.
- **Rationale**: Directly implements FR-005 and edge case 1 (missing entity →
  refuse partial bone) with a check that runs in milliseconds on stubs.
- **Alternatives considered**: full analyzer-based resolution (rejected: pulls
  in the analyzer for stub files that only ever import `dart:core` siblings —
  massive overkill).

## Best-practice notes (from codebase survey)

- Plugin shape: `lib/src/plugins/<name>/` with `<name>_plugin.dart`,
  `builders/`, `generators/` — followed exactly.
- File emission: return `List<GeneratedFile>` from `generateWithContext`;
  let `FileUtils.writeFile` / `TransactionalFileSystem` do the writes —
  never `dart:io` writes inside builders (export's tar.gz is the one
  exception, writing a single binary artifact).
- Dart stubs: build with `code_builder`, format with `dart_style`, matching
  every other generator in the repo.
- Tests: `test/plugins/skeleton/` mirrors the plugin layout; default fast
  suite (`dart test`), no slow-tier tags needed.
