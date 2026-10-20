# Bug Assessment: `zfa build`'s registrar refresh clobbers a hand-authored `hive_registrar.dart`, then the combining builder fails

- **Slug**: registrar-clobbers-placeholder
- **Created**: 2026-10-20
- **Source**: https://github.com/arrrrny/zuraffa/issues/1953
- **Verdict**: valid (root cause confirmed in code; the #1732 refresh rewrites a hand-curated registrar host on every build)
- **Severity**: high (leaves the consumer tree with a broken generated file after a failed build, on every `zfa build`)

## Report

Issue #1732 made `zfa build` refresh the Hive registrar host library before
build_runner runs (`BuildCommand.refreshHiveRegistrar`), so the host's import
block stays in step with its `.g.dart` part. The refresh regenerates the file
through `CacheBuilder` with `force: true` and its emission is fixed-shape: an
un-hided `import 'package:zuraffa/zuraffa.dart';`, relative entity imports, the
`part 'hive_registrar.g.dart';` directive, and zero comments beyond the
GENERATED marker wrap. A consumer that hand-authors
`lib/src/cache/hive_registrar.dart` (the
`docs/hand-authored-g-dart-placeholders.md` pattern — the zik_zak app pins
`import 'package:zuraffa_flutter/zuraffa_flutter.dart' hide DeviceInfo;` to
dodge the known `DeviceInfo` ambiguous-import collision) gets that curation
wholesale-replaced on every build. The rewritten host re-imports
`package:zuraffa/zuraffa.dart` un-hided, reintroduces the ambiguous import, and
the build dies at `source_gen:combining_builder` — after the file was already
clobbered, so the working tree is left broken.

Spec 1540's `TrackedGeneratedOutputGuard` does not cover this: it protects
*generated-name* files (`.g.dart` / `.zorphy.dart`) from *deletion*; the
registrar host is neither.

## Symptom

`zfa build` in a project with a hand-authored registrar: the file's curated
import block is replaced (diff shows the `hide DeviceInfo` import dropped, an
un-hided `package:zuraffa/zuraffa.dart` added), then the build fails exit 1 at
`source_gen:combining_builder` on `lib/src/cache/hive_registrar.dart`.

## Reproduction

In-process (no subprocess, mirroring
`test/commands/build_command_hive_registrar_refresh_test.dart`): sandbox
project with one entity, one `*_cache.dart`, and a registrar carrying a
`hide` combinator import + comment lines + the part directive (the real zik_zak
shape) → `BuildCommand.refreshHiveRegistrar(projectRoot: sandbox)` → on the
unfixed tree the file bytes change (clobber: `refreshed: true`,
`clobbered: true`, the curated `hide DeviceInfo` import gone, replaced by the
un-hided `package:zuraffa/zuraffa.dart` emission); the fix makes the refresh
refuse with the documented remedy and leave the bytes untouched.

## Suspected Code Paths

- `lib/src/commands/build_command.dart` — `refreshHiveRegistrar` (the
  clobbering writer during `zfa build`), and the final build-failure branches
  for the ask-2 diagnostic re-print.
- `lib/src/plugins/cache/builders/cache_builder_registrar.dart` — the emission
  shape the hand-authorship detector is derived from (the GENERATED marker
  wrap via `SpecLibrary.emitLibrary`, no import combinators, always the part
  directive).
- `lib/src/core/builder/shared/spec_library.dart` — the
  `wrapWithGeneratedMarkers` wrap every emission carries, which bounds the
  only comment lines a generated registrar may have.
- `lib/src/core/generation/tracked_generated_output_guard.dart` — prior art for
  the remedy message (`kHandAuthoredPlaceholderDoc`).

## Remediation

1. **Refuse, don't clobber**: `refreshHiveRegistrar` detects a hand-authored
   registrar (any comment line beyond the `// GENERATED - DO NOT EDIT` …
   `// END GENERATED` wrap, any `hide`/`show`/`as` import combinator, or a
   missing part directive / marker wrap — bytes the generator never emits)
   and refuses with a loud no-op pointing at the documented `build.yaml`
   `generate_for.exclude` fix. The explicit `zfa cache adapter` command keeps
   its contract (the operator asked for regeneration); the guard covers the
   implicit every-build path the issue reports.
2. **Combining-builder diagnostic**: when the build (and its clean-cache
   retry) fail, a `source_gen:combining_builder` failure in the captured
   output is re-printed — its own section, immediately before the exit
   verdict — so the diagnostic survives output wrappers that truncate the
   live stream, with the hand-authored-placeholder remedy named.
