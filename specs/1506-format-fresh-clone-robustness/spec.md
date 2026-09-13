# Feature Spec: dart format Robustness in a Fresh Clone [SPEC 1506]

**Feature ID:** 1506-format-fresh-clone-robustness
**Issue:** #1506
**Related:** #1509 (toolchain path), CI `format` job (`.github/workflows/ci.yaml`)
**Status:** IMPLEMENTED

## Summary

Running `dart format lib test` in a fresh clone — before any package
resolution has happened — emits a `Package resolution error` warning for
every formatted file and rewrites hundreds of unrelated files:

```text
Warning: Package resolution error when reading "analysis_options.yaml" file for "lib/agent.dart":
Failed to resolve package URI "package:lints/recommended.yaml" in include at "<root>/analysis_options.yaml".
...
Formatted 2591 files (868 changed) in 6.88 seconds.
```

Reproduced on Dart 3.13.2 (the SDK CI pins for the format gate): a fresh
clone with no `.dart_tool/` rewrites **868 files, 11,616 insertions,
13,550 deletions**. After `dart pub get --no-example` the identical
command is a no-op: **`Formatted 2591 files (0 changed)`**.

## Problem

Root cause (reproduced on Dart SDK 3.13.2, 2026-09-13):

1. `dart format` reads `analysis_options.yaml` for every formatted file to
   resolve formatter options. The root options file opens with
   `include: package:lints/recommended.yaml` (analysis_options.yaml:1).
2. Without a package config (`.dart_tool/package_config.json`), the
   `package:` URI cannot be resolved → dart format warns **per formatted
   file** and falls back to default formatting rules.
3. The fallback rules differ from the resolved configuration, so the
   formatter rewrites the whole tree — 853–868 files including every file
   unrelated to whatever the developer actually touched.

Surfaces in this repository that can trigger the failure mode:

- **Developer workflow** (the issue reproduction): `dart format lib test`
  in a fresh clone. Documented as a hard rule in AGENTS.md:42 with NO
  pub-get precondition.
- **Agent workflow template** (`.github/agents/surgical-pr-fix.agent.md:79`):
  `dart format <touched files>` — correctly scoped, but with no pub-get
  precondition, a fresh-clone run still warns per file (and on a
  `<touched files>` scope the rewrite blast radius is contained; the
  warning spam is not).
- **CLI generation flow** (`lib/src/commands/entity_command.dart:1427`):
  `_runFormat()` spawns `dart format .` — the ENTIRE package tree,
  including `test/`, `bin/`, `tool/`, `corpus/`, `examples/` — far beyond
  the entity files the command just wrote. In a consumer project without
  package resolution this is the worst-case invocation: whole-tree
  rewriting with per-file warning spam.
- **CI format job** (`.github/workflows/ci.yaml:133-151`): ALREADY
  compliant — `dart pub get --no-example` runs before
  `dart format --set-exit-if-changed lib test`, with a comment explaining
  exactly this failure mode. No change required (verified 2026-09-13).
- **TDD pass registry** (`lib/src/plugins/tdd/services/refactor_passes.dart:266`):
  format pass command `dart format lib/`. The command string is pinned by
  the pass-registry test corpus (`refactor_action_test.dart`,
  `refactor_command_test.dart:185`, `bug_1311`, `bug_1430`,
  `incremental_verify_test.dart`) and recorded verbatim in refactor
  receipts — changing it is a refactor-machinery (state machine) change,
  EXCLUDED by this spec's hard constraints. The TDD refactor flow runs in
  a project whose tests must resolve to execute, so the fresh-clone
  precondition does not apply to it in practice.

## Requirements

### FR-1 — FormatRunner: pub-get enforcement before every format invocation

A single injectable format runner (`FormatRunner`,
`lib/src/core/format/format_runner.dart`) is the format path for the
generation commands — the TDD refactor pass registry
(`refactor_passes.dart`) runs its own `dart format lib/` and is tracked
separately. Before spawning the formatter it verifies package
resolution (`.dart_tool/package_config.json` exists under the working
directory). When resolution is missing it runs `dart pub get --no-example`
first; the CLI names that side effect (it can rewrite `pubspec.lock`). If
that fails, the format invocation is SKIPPED and exactly ONE actionable
warning is emitted — the runner must never spawn `dart format` without
package resolution, so the per-file warning spam is unreachable through
the CLI.

### FR-2 — FormatRunner refuses tree-wide scopes

`FormatRunner.formatPaths` rejects scopes that format the whole tree —
`.` / `./`, `..`, and any path resolving to the package root or above —
with an `ArgumentError` BEFORE any process is spawned. The whole-tree
invocation is the blast-radius amplifier the issue reports; the guard
resolves each scope before comparing, so the invariant is mechanical
rather than literal-equality.

### FR-3 — Scope-limited formatter invocations in CLI flows

`EntityCommand._runFormat()` (the only CLI flow that currently formats)
invokes the formatter scoped to the generated entity output tree
(`lib/src/domain/entities`) instead of `.`. The entity flow writes only
under that tree (create/add-field/enum/from-json all target
`fixedEntityOutput`), so the scope covers exactly the intended files and
never `test/`, `bin/`, `tool/`, `corpus/`, or `examples/`.

### FR-4 — Pub-get enforcement in the documented workflows

The two documents that prescribe formatting to developers and agents
(AGENTS.md hard rule; `.github/agents/surgical-pr-fix.agent.md` verify
step) are amended to enforce `dart pub get --no-example` before any
formatter invocation. CI already enforces this order (documented, no
change).

## Success Criteria (measurable)

1. On a fresh clone of this repository (no `.dart_tool/`), the CLI-driven
   format path cannot emit the repeated `Package resolution error`
   warning: with no package config the runner either establishes
   resolution (pub get) or skips formatting with a single warning —
   a `dart format` process is NEVER spawned without resolution.
2. After `dart pub get --no-example`, `dart format lib test` is a no-op:
   `Formatted N files (0 changed)` (verified on Dart 3.13.2).
3. The CLI format invocation for entity generation targets
   `lib/src/domain/entities` only — never `.` and never a bare `lib` /
   `test` tree; a tree-wide scope raises `ArgumentError` before spawning.
4. `dart pub get --no-example` precedes `dart format` in every documented
   workflow (AGENTS.md, surgical-pr-fix agent template) and in CI
   (already the case).
5. `dart analyze lib test` reports zero new issues vs the pre-change
   baseline (0 errors / 112 pre-existing infos).

## Hard Constraints (from the issue)

- Fix ONLY the format invocation patterns and pub-get enforcement. Do NOT
  change test logic, the make command, or the TDD state machine. The TDD
  refactor pass registry (`dart format lib/` pass) is OUT OF SCOPE — its
  command string is receipt-pinned and covered by the state-machine
  constraint.
- Must pass `dart analyze` with no new warnings.
