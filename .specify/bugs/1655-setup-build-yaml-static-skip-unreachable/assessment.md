# Bug Assessment: #1641's static first-build skip is unreachable for zfa setup-created apps — setup itself ships the build.yaml that forces the first build

- **Slug**: 1655-setup-build-yaml-static-skip-unreachable
- **Created**: 2026-09-15T16:44:34Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1655
- **Verdict**: valid (root cause confirmed in code; the static skip's build.yaml trigger is dead code on every app the canonical workflow creates)
- **Severity**: high (every fresh-app first refactor pays the ~4 min entrypoint AOT compile that #1634/#1641 exist to avoid)

## Report

PR #1641 (issue #1634) added a static first-build decision to
`BuildRelevance.refactorBuildSkipNote`: when build_runner has no state at all
(no `.dart_tool/build/`), a source scan decides whether the first build has
anything to emit. One of its triggers (doc'd 1c) is the mere EXISTENCE of
`build.yaml` at the project root. But `zfa setup` unconditionally writes
`build.yaml` as one of its standard steps (`DependencyWirer.ensureProjectStructure`
→ `buildYamlContent`), so on EVERY app created by the canonical workflow the
static skip can never fire — the gate falls through to running the first build,
which pays the one-time `dart compile aot-snapshot` of build.dart +
`gen_snapshot` (~380s measured, A1 refactor 890s vs 420.6s in the #1634
measurement). Refactors after the graph exists skip correctly (A2 1.3s) — the
gap is exactly and only the first build.

## Symptom

The first refactor on a fresh `zfa setup` app still runs `zfa build` →
`dart compile aot-snapshot` of `.dart_tool/build/entrypoint/build.dart` →
`gen_snapshot` writing `build.dart.aot`, even though the app has zero
builder-facing files (the exact fresh-app TDD shape #1634 targets: spec-driven,
no entities yet).

## Reproduction

1. `zfa setup calculator_x --platforms=macos` (writes `build.yaml` as part of
   step 3, "Creating build.yaml + domain structure").
2. `zfa plugin enable … x31`; `zfa tdd init`; drop a 10-behavior calculator
   spec (no entities, no annotated files anywhere); `zfa tdd plan calculator_x`.
3. `zfa tdd run calculator_x --stream` (born-green ×2, issue #1488 hand step).
4. `zfa tdd run calculator_x --stream` — run #2 → the first refactor.
5. Observe `dart compile aot-snapshot` / `gen_snapshot` of
   `.dart_tool/build/entrypoint/build.dart` inside the refactor window; total
   ≈ 890s instead of the expected ≈ 50–75s static-skip refactor.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/build_relevance.dart` —
  `_staticFirstBuildSkipNote` (the #1634 static first-build decision), the
  check `if (File(p.join(projectRoot, 'build.yaml')).existsSync()) return null;`
  (the doc's rule 1c). This is the only trigger whose presence is NOT
  content-derived: `zfa setup`/`zfa init`/the `zfa build` guard all write the
  file unconditionally, so its existence cannot discriminate "nothing
  builder-facing" — the exact standard the docstring already applies to the
  OTHER config files ("they exist on every app, so their presence cannot
  discriminate", #1634 doc lines 82–84).
- `lib/src/core/dependencies/dependency_wirer.dart` —
  `DependencyWirer.buildYamlContent` (the single static template
  `zfa setup`, `zfa init`, and the `zfa build` guard
  (`build_yaml_guard.dart` `BuildYamlGuard.scaffold`) all write
  byte-for-byte). This const is the natural provenance discriminator the
  static rule currently lacks.
- History that constrains the fix: #1587 (the make's fingerprint gate),
  #1624 (the refactor build-pass gate + marker freshness), #1634/#1641 (the
  static first-build decision this bug repairs).

## Root Cause Hypothesis (confirmed by code reading)

The static first-build rule uses build.yaml EXISTENCE as a builder-facing
signal. That precondition can never hold for a `zfa setup` app: setup writes
the file in the same breath that creates the app, its mtime is setup's final
second, and the fresh-app TDD scenario (spec-driven, zero annotated files) is
exactly the state "build.yaml present + nothing builder-facing". The trigger
is therefore dead code on every app the canonical workflow creates, and the
gate fails through to running the first build (the #1634 cost the static path
was written to avoid). The docstring's own discriminator standard — "their
presence cannot discriminate" — applies to setup's build.yaml too; the rule
just never encoded it.

## Proposed Remediation

Remedy 1 from the issue (provenance marker), strengthened to handle the
"edited" case the marker alone cannot: treat a build.yaml as non-discriminating
ONLY when it is byte-identical to the known generated template
(`DependencyWirer.buildYamlContent` — the single source of truth `zfa setup`,
`zfa init`, and the `zfa build` guard already share). Concretely:

1. `DependencyWirer.buildYamlContent` gains a `# zfa:generated …` provenance
   header (the issue's recognizable generated header — documents the file's
   origin to end users; the const itself remains the exact-match template).
2. `_staticFirstBuildSkipNote` reads the build.yaml content and treats it as
   non-discriminating iff it matches the template byte-for-byte; any other
   content (user-authored, user-modified, or an older CLI's template) keeps
   today's behavior and runs the first build — the conservative direction.
   A pristine template build.yaml then falls through to the existing scan
   (non-Dart sources, builder-facing annotations), so a pristine build.yaml
   PLUS an annotated source still runs.
3. Update `staticFirstBuildSkippedNote` and the library/`refactorBuildSkipNote`
   docs to state the new rule honestly.
4. The incremental freshness logic (marker-mtime rules 2–6) is untouched; the
   build pass, the asset-graph writer, and `zfa build` are untouched (hard
   constraint honored).

## Files likely to change

- `lib/src/core/dependencies/dependency_wirer.dart` (template header —
  remedy 1's "recognizable generated header")
- `lib/src/plugins/tdd/services/build_relevance.dart` (the static rule + notes)
- `test/plugins/tdd/services/build_relevance_test.dart` (the #1655 tests)
- `test/core/dependencies/dependency_wirer_test.dart` (marker contract pin)

## Tests to add or update

- RED (the #1655 bug): a fresh app whose build.yaml is the pristine
  `DependencyWirer.buildYamlContent` and whose sources have nothing
  builder-facing skips the first build statically.
- Guard (criterion 2): a USER-AUTHORED build.yaml (any content that is not the
  template) still runs the first build — the existing #1634 test covers this
  shape; keep it green.
- Guard (criterion 2, edited shape): the setup template PLUS a user edit runs
  the first build.
- Guard (criterion 1 fall-through): the pristine template PLUS a
  builder-facing annotation still runs the first build.
- Pin: `DependencyWirer.buildYamlContent` carries the `zfa:generated`
  provenance header (the marker contract between the writer and the gate).

## Risks & Considerations

- Template drift: an app whose build.yaml was written by an OLDER CLI whose
  template differed no longer matches the current const → forces the first
  build = today's behavior (conservative, never a fabricated skip).
- Exact byte match is deliberately strict: editor line-ending churn or any
  user touch flips the file to "authored" and restores the build. The skip is
  an optimization; the run is always sound.
- The failure contract is unchanged: every read/stat error in the static path
  still fails the decision toward RUN via the existing catch.
- Acceptance criterion 3 (entrypoint AOT compile eliminated or paid during
  setup) is met by the static skip — the compile is never reached on the
  fresh-app path with nothing builder-facing.

## Open Questions

- None. The issue names remedy 1 as sufficient; the exact-match refinement is
  strictly inside its "marker-bearing, unmodified" wording.
