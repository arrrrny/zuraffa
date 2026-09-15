# Bug Issue: perf(1634): #1641's static first-build skip is unreachable for zfa setup-created apps

- **Slug**: 1655-setup-build-yaml-static-skip-unreachable
- **Fetched**: 2026-09-15T16:44:34Z
- **Issue**: 1655
- **URL**: https://github.com/arrrrny/zuraffa/issues/1655
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, build, tdd

## Body

# bug(1634): #1641's static first-build skip is unreachable for `zfa setup`-created apps — setup itself ships the `build.yaml` that forces the first build, so the entrypoint AOT compile is still paid inside the first refactor

## Repro (canonical workflow, fresh app)

```
zfa setup calculator_x --platforms=macos     # writes build.yaml as its last act
zfa plugin enable … x31
zfa tdd init
# drop 10-behavior calculator spec (no entities, no annotated files anywhere)
zfa tdd plan calculator_x
zfa tdd run calculator_x --stream
# acceptance hand step (issue #1488) → born-green ×2
zfa tdd run calculator_x --stream            # run #2 → first refactor
```

## Expected

PR #1641 (issue #1634): the first refactor on a fresh app with no builder-facing
files skips the build pass statically — no `gen_snapshot`, refactor ≈ 50–75s.

## Actual (measured today, zfa v6.3.0 built from f011e3fb, includes #1641)

The first refactor still runs `zfa build` → `dart compile aot-snapshot` of
`.dart_tool/build/entrypoint/build.dart` → `gen_snapshot` writing
`build.dart.aot`. Process sampler (5s cadence) across the refactor window:

- `dart compile aot-snapshot --packages <app>/.dart_tool/package_config.json <app>/.dart_tool/build/entrypoint/build.dart` first seen ~240s into the refactor (after the full-suite preflight)
- `gen_snapshot` present in **76 consecutive samples (~380s)**, pids 36025→37307, all writing `<app>/.dart_tool/build/entrypoint/build.dart.aot`
- A1 refactor total: **890s** (vs 420.6s in the #1634 measurement; caveat: a parallel agent `zfa tdd run` on another app was contending — but the ~380s compile is attribution-clean: output path is this app's `build.dart.aot`)
- the refactors AFTER the graph exists skip their build pass correctly (A2 1.3s, U2 59.2s) — the gap is exactly and only the first build

## Root cause (traced)

`refactorBuildSkipNote`'s static first-build rule
(`lib/src/plugins/tdd/services/build_relevance.dart`, doc at lines 68–92, check
at line 417):

```dart
if (File(p.join(projectRoot, 'build.yaml')).existsSync()) return null; // run the build
```

`zfa setup` **unconditionally writes `build.yaml`** (configuring
`zorphy:zorphy`, `json_serializable`, `source_gen:combining_builder` over
`lib/src/**` and `test/**`) — its mtime is setup's final second. The docstring
already articulates the exact discriminator standard the trigger must meet
("they exist on every app, so their presence cannot discriminate") — but that is
true of setup's `build.yaml` too. On any app created by the canonical workflow
the static skip is dead code, and the gate falls back to running the first
build, which pays the one-time entrypoint AOT compile. Fresh-app TDD (the
#1634 scenario: spec-driven, no entities yet) is exactly the state where the
app has a build.yaml and zero annotated files.

## Why this matters

Issue #1634 measured the same ~4 min compile. The fix works as coded — the gap
is that its precondition ("no builder-facing files") can never hold for a
`zfa setup` app. Every fresh-app first refactor pays it.

## Suggested remedies (any one suffices)

1. **Provenance marker**: `zfa setup` emits `build.yaml` with a recognizable
   generated header (e.g. `// zfa:generated — re-run zfa setup to regenerate`);
   the static rule treats a marker-bearing, unmodified build.yaml as
   non-discriminating. A user-authored build.yaml (no marker, or edited)
   still forces the build.
2. **Content-aware check**: instead of existence, parse the build.yaml's
   enabled builders' `generate_for` globs and check whether any EXISTING file
   matches a builder-facing annotation; zero matches → skip. (Our repro app:
   build.yaml enabled zorphy over `lib/src/**` + `test/**` with zero
   annotated files, yet the build ran.)
3. **Warm during setup**: run the entrypoint AOT compile once during
   `zfa setup` (off the TDD critical path). Keeps the cost one-time and
   user-visible in a phase where a slow step is expected, instead of inside
   the first refactor where it reads as a hang.

## Evidence files

- sampler log window + phase timeline: `/tmp/zfa-measure/procs.log`,
  `/tmp/zfa-measure/timeline.tsv` (labels 81-*, app `~/Developer/calculator_x`)
- prior measurement: issue #1634 (420.6s first refactor, same compile)


## Comments

None.
