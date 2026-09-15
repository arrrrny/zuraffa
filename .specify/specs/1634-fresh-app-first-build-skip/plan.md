# Implementation Plan: 1634-fresh-app-first-build-skip

- **Branch**: feat/1634-fresh-app-first-build-skip
- **Spec**: .specify/specs/1634-fresh-app-first-build-skip/spec.md
- **Date**: 2026-09-15

## Technical Context

Language/Version: Dart SDK ^3.11.0 (resolved 3.13.4 in this workspace),
pure-Dart package (no Flutter import in the touched files).
Key files:

- `lib/src/plugins/tdd/services/build_relevance.dart` — the gate
  (`BuildRelevance`): make-side fingerprint gate (#1587, untouched) +
  refactor-side marker gate (#1624, extended here).
- `lib/src/plugins/tdd/services/refactor_passes.dart` — the pass
  registry; the gate is bound to the `build` spec via
  `defaultPassSpecs` and a non-null note records a synthetic skipped
  action (`RefactorAction(skipped: true, exitCode: 0, filesChanged:
  const [], output: note)`). NO change required here.
- `test/plugins/tdd/services/build_relevance_test.dart` — gate tests
  (the #1624 group's "missing marker" test asserts the fail-open being
  replaced; updated per the spec, every other #1624 test byte-identical).
- `test/plugins/tdd/services/refactor_passes_test.dart` — the binding
  test whose scratch project (empty `lib/`, no pubspec, no
  `.dart_tool/build/`) exercises the NEW static path at its first
  assertion (line ~357).

## Technical Decisions

### D1 — Remedy selection: static skip (issue remedy 1), not JIT / setup-warm

The issue offers three remedies. Remedy 1 (decide statically when no
build_runner state exists) is chosen because it (a) eliminates the AOT
compile for the reported class (features that never generate anything)
instead of merely moving it, (b) is testable as pure decision logic in
temp-dir unit tests, and (c) touches ONE method — the narrowest blast
radius under the "first-build decision only" hard constraint. Remedies
2 (`--force-jit` first build) and 3 (setup-time warm) would both touch
the build pass itself, which the constraint forbids.

### D2 — Static-path reachability: no `.dart_tool/build/` directory at all

The static decision runs only when the `asset_graph.json` marker is
missing AND `.dart_tool/build/` does not exist. A directory without the
marker (mid-build / partially cleaned) is an UNKNOWN — it fails open
(runs). Rationale: the issue's remedy text says "if no
`.dart_tool/build/` exists at all"; a fresh `zfa setup` app has no such
directory, and `dart pub get` creates only `.dart_tool/package_config.json`.
After a static skip the directory still does not exist, so every later
refactor re-enters the static path until a real build creates the graph
— self-consistent.

### D3 — Static RUN triggers: annotations, non-Dart files in roots, build.yaml

The static question differs from the incremental one: not "what changed
since the last build" but "can ANY file here feed a builder". Triggers
(any one → run):

1. A non-Dart file inside the walked roots (`lib/`, `test/`, `bin/`,
   `tool/`) — slang translation sources, assets (same rule as
   incremental step 4).
2. A `.dart` file whose RAW content matches
   `BuildRelevance.builderFacingAnnotation` (same matcher verbatim —
   comments count, fail-safe direction).
3. A `build.yaml` at the project root. `zfa build`'s guard
   auto-scaffolds `build.yaml` when missing
   (`lib/src/commands/build_yaml_guard.dart`), so a never-built app has
   none; its presence without a graph means someone configured builders
   (or a prior build scaffolded it and `.dart_tool` was cleaned) — run.

Deliberately NOT triggers: `pubspec.yaml`, `pubspec.lock`,
`analysis_options.yaml`, `dart_test.yaml`, `.zfa.json`,
`.dart_tool/package_config.json`. These exist on EVERY app, fresh or
not — their mere presence cannot discriminate "nothing builder-facing",
so treating them as triggers would disable the static skip forever and
re-create the #1634 bug. Builder registration lives in `build.yaml`
(D3.3); build_runner emits nothing from a pubspec alone without
annotated inputs or builder-configured sources, and the
annotated/non-Dart triggers cover those.

### D4 — The new note: honest about what the static scan can and cannot prove

`staticFirstBuildSkippedNote` (new constant, sibling of
`refactorBuildSkippedNote`) names issue #1634 and states: build_runner
has never run here (no `.dart_tool/build/`), the static scan found no
builder-facing annotation, no non-Dart source inside the walked roots,
and no `build.yaml` — so a first build would emit nothing and the
one-time entrypoint AOT compile is not paid. It states the trade-offs
explicitly: the skipped `zfa build`'s whole-project
`dart analyze lib/` stage was skipped with it (these plain-Dart writes
were not analyzer-graded), and a project copied WITHOUT
`.dart_tool/` whose committed generated outputs reference otherwise
un-annotated sources is outside the scan's model — the absolute-green
preflight bounds that blast radius (a missing `part` target breaks
compilation before the passes run), mirroring the incremental note's
deletion-blind-spot honesty.

### D5 — Error contract: catch everything, fail toward RUN

The static scan re-raises nothing: a decode error (invalid UTF-8), an
unreadable stat, or a file vanished mid-walk returns null (run),
identical to `shouldSkipTerminalBuild` (#1587 review finding 1) and
`refactorBuildSkipNote` (#1624). A hiccup must never fabricate a skip.

### D6 — Test strategy: temp-dir decision tests + one binding-test update

All behavior is pure decision logic over a Directory — the existing
test style (`Directory.systemTemp.createTempSync`, real files,
backdated mtimes where needed — the static path needs NO mtime
backdating, which also makes it immune to coarse-mtime flakiness).
The #1624 "missing marker runs the build" test is REWRITTEN into the
fresh-app static matrix (it asserted exactly the behavior #1634
removes); all other #1624 tests stay byte-identical (SC-4). The
`refactor_passes_test.dart` binding test's first assertion flips from
`isNull` to the static skip note — the scratch project (empty `lib/`)
is precisely the US1 shape.

## Risks & Mitigations

- **Fabricated skip on a project that needed the build** → conservative
  trigger set (D3), fail-open on unknowns (D2) and errors (D5); the
  absolute-green preflight bounds residual cases (D4).
- **Mtime flakiness** → not applicable: the static path compares no
  mtimes (only existence + content), unlike the incremental path.
- **Test drift on the #1624 group** → only the missing-marker test is
  rewritten; the rest must remain byte-identical (checked in analyze).
- **Scope creep** → one method + one constant + class doc; no changes
  to `refactor_passes.dart`, the make gate, or the build command.

## Migration / Rollout

No configuration, no data migration, no public API change (a new
public constant on an existing service class, matching the existing
`refactorBuildSkippedNote` precedent). Behavior change is
forward-only: apps that already built keep the incremental path.
