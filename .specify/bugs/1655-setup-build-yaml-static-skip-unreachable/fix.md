# Bug Fix: #1641's static first-build skip is unreachable for zfa setup-created apps

- **Slug**: 1655-setup-build-yaml-static-skip-unreachable
- **Fixed**: 2026-09-15 (this session)
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ../tdd/test-list.md, ../tdd/verification.md, ./red-evidence.md

## Summary

The static first-build decision (`BuildRelevance._staticFirstBuildSkipNote`)
no longer treats a build.yaml as builder-facing evidence from its EXISTENCE
alone. `zfa setup`, `zfa init`, and the `zfa build` guard all write the SAME
byte-identical registration (`DependencyWirer.buildYamlContent`), so the gate
now reads the content: a build.yaml byte-identical to that template is
setup-generated and unmodified — non-discriminating exactly like the other
every-app config files — and falls through to the existing static scan
(non-Dart sources, builder-facing annotations). Any other content
(user-authored, user-edited by a single byte, or an older CLI's template) is
user-owned and keeps the #1634 behavior: run the first build. On the reported
fresh-app shape (setup-created, spec-driven, zero annotated files) the first
refactor now skips the build pass statically and never pays the ~4 min
entrypoint AOT compile.

Remedy 1 from the issue (provenance marker), strengthened to the
"unmodified" half the issue's wording already demanded: the template carries
a `# zfa:generated` provenance header (visible to end users), and the gate
recognizes the template by exact content match — which is what makes the
"edited" case sound where a substring marker check alone would not be.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/build_relevance.dart` | modified | `_staticFirstBuildSkipNote` reads build.yaml content and returns null (run) only when it is NOT byte-identical to `DependencyWirer.buildYamlContent` (new `_isPristineGeneratedBuildYaml` helper); a pristine generated registration falls through to the unchanged scan. Library doc (#1634 paragraph), `refactorBuildSkipNote` rule 1c, `_staticFirstBuildSkipNote` doc, and `staticFirstBuildSkippedNote` updated to state the #1655 rule. The incremental freshness logic (marker-mtime rules 2–6), the note strings' honesty contract, and the fail-toward-RUN error contract are untouched. |
| `lib/src/core/dependencies/dependency_wirer.dart` | modified | `buildYamlContent` gains the `# zfa:generated` provenance header (4 YAML comment lines) + a doc comment naming it the #1655 provenance discriminator shared by `zfa setup`, `zfa init`, and `BuildYamlGuard.scaffold`. No executable-code change; the builder registration body is byte-identical, so `builder_dependency_preflight`'s YAML parse of the template is unaffected. |
| `test/plugins/tdd/services/build_relevance_test.dart` | added tests | The #1655 group: pristine setup template skips statically (the bug, RED pre-fix); pristine template + @Zorphy annotation runs; MODIFIED template runs (criterion 2); pristine template + non-Dart source runs. The existing user-authored build.yaml test re-commented as the criterion-2 shape it already pins. |
| `test/core/dependencies/dependency_wirer_test.dart` | added test | Pin: `buildYamlContent` starts with `# zfa:generated` (the marker contract between the writer and the gate; independent literal, not a copy). |

## Diff Highlights

The behavioral core — existence is no longer the discriminator:

```dart
// BEFORE (issue #1655): setup ships build.yaml to every app it creates,
// so this trigger was dead code on the exact fresh-app shape #1634 targets.
if (File(p.join(projectRoot, 'build.yaml')).existsSync()) return null;

// AFTER: read the content — a pristine generated registration cannot
// discriminate "nothing builder-facing"; anything user-owned still runs.
final buildYaml = File(p.join(projectRoot, 'build.yaml'));
if (buildYaml.existsSync()) {
  final content = await buildYaml.readAsString();
  if (!_isPristineGeneratedBuildYaml(content)) return null;
}
```

```dart
static bool _isPristineGeneratedBuildYaml(String content) =>
    content == DependencyWirer.buildYamlContent;
```

## Hard constraints honored

- The build pass itself, the asset-graph writer, and the incremental
  freshness logic (marker-mtime rules 2–6) are untouched — the diff touches
  only the static first-build decision (its trigger, its docs, its skip
  note) and setup's template string.
- One PR per bug; closes #1655 as a follow-on to #1634/#1641.
