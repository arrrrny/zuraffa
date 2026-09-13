# Implementation Plan: dart format Robustness in a Fresh Clone [SPEC 1506]

**Feature ID:** 1506-format-fresh-clone-robustness
**Issue:** #1506
**Spec:** [spec.md](spec.md)

## Technical Context

- **Language/Runtime:** Dart 3.13.2 (SDK CI pins for the format gate); root
  package `zuraffa` (`sdk: ^3.11.0`), pure-Dart CLI.
- **Formatter behavior (verified):** `dart format` reads
  `analysis_options.yaml` per formatted file; the root file's
  `include: package:lints/recommended.yaml` fails to resolve without
  `.dart_tool/package_config.json`, producing per-file warnings and
  default-rule fallback formatting (868 files rewritten in reproduction).
- **Package resolution precondition:** `dart pub get --no-example`
  succeeds on a pure-Dart SDK (the `example/` sub-package needs Flutter,
  hence `--no-example`, matching CI). After it,
  `dart format lib test` is a no-op (0 changed).

## Technical Decisions

### D1 — One injectable runner, not scattered guards

`FormatRunner` (`lib/src/core/format/format_runner.dart`) centralizes:
resolution check → optional `dart pub get --no-example` → scoped
`dart format <paths>`. Injectable process runner follows the
`PubspecProcessRunner` typedef convention (`pubspec_auto_add.dart:36`)
so tests stay hermetic (the `entity_builder_preflight_test.dart`
`_RecordingRunner` pattern). Rationale: the defect is a MISSING
precondition, not a wrong flag — the fix must be structurally impossible
to bypass from CLI flows rather than re-documented at each call site.

### D2 — Skip-with-single-warning beats fail-hard

When resolution cannot be established, formatting is skipped with ONE
actionable warning (`flutter pub get` remediation hint for Flutter hosts)
instead of failing the command: formatting is a convenience tail of
generation flows (exit code of the generation command must not regress),
and a hard failure would change make/entity exit semantics beyond this
spec's constraints. The skip is observable in the structured result
(`skipped`, `warning`) for callers that want to surface it.

### D3 — Scope source: the command's output contract

`EntityCommand` writes Dart outputs only under
`ZfaConfig.fixedEntityOutput` (`lib/src/domain/entities`) — verified for
create (`outputDir = fixedEntityOutput`), add-field
(`EntityCreator(baseOutputDir: fixedEntityOutput)`), enum
(`enumTarget` under `fixedEntityOutput`), from-json (entities into the
same tree). The format scope is therefore
`[ZfaConfig.fixedEntityOutput]` — precisely the intended files, no
per-run path collector needed (which would touch every handler for no
behavioral gain).

### D4 — Tree-wide guard is an ArgumentError, not a warning

`formatPaths(['.'])` throws BEFORE spawning: a whole-tree format is
never intended in a CLI flow, and a warning could be scrolled past (the
issue is precisely a whole-tree rewrite nobody wanted).

### D5 — Out of scope (constraints)

- TDD pass registry format pass (`refactor_passes.dart`) — command string
  is pinned by `refactor_action_test.dart`,
  `refactor_command_test.dart:185`, `bug_1311`, `bug_1430`,
  `incremental_verify_test.dart` and recorded verbatim in refactor
  receipts; changing it is a state-machine change.
- Make command — untouched (hard constraint).
- CI `format` job — already enforces `dart pub get --no-example` before
  the tree-wide CHECK (`--set-exit-if-changed` never rewrites); the gate
  stays tree-wide deliberately: with resolution enforced it is the exact
  control that catches formatter drift.

## Verification Strategy

- Unit tests (`test/commands/format_runner_1506_test.dart`): hermetic
  runner-recorder cases for FR-1 (order + enforcement), FR-2 (guard),
  and the skip path; resolution check is a real
  `.dart_tool/package_config.json` fixture in a temp project.
- Integration test (`test/commands/entity_format_scope_1506_test.dart`):
  in-process `EntityCommand.execute(['create', ..., '--dart-format'])`
  (SPEC 917 embedded mode, `entity_builder_preflight_test.dart` fixture
  pattern) with an injected recording FormatRunner — asserts the format
  invocation targets the entity tree and the pub-get enforcement order.
- Full-suite lane: `dart analyze lib test` (baseline 0 errors / 112
  infos, no new) + targeted `dart test` files.

## Risks / Trade-offs

- **Scope narrower than `.`**: a consumer who relied on
  `zfa entity create --dart-format` to format unrelated hand-written
  files loses that accident. Accepted: tree-wide formatting as a side
  effect is the defect class under fix; `dart format` remains available
  explicitly.
- **`--no-example` on pub get**: matches CI exactly; consumer projects
  without an `example/` are unaffected.
- **Flutter-host consumer projects**: `dart pub get --no-example` may
  fail where only `flutter pub get` works → runner skips formatting with
  the remediation warning (D2), command still succeeds.
