# tdd.verify — Bug #1655 the static first-build skip is unreachable for zfa setup-created apps

- **Verified**: 2026-09-15, this session, on
  `fix/1655-setup-build-yaml-static-skip-unreachable` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/plugins/tdd/services/build_relevance.dart` (the static
  first-build trigger + docs + skip note), `lib/src/core/dependencies/
  dependency_wirer.dart` (template provenance header — doc + string const,
  no executable-code change), the new #1655 tests in
  `test/plugins/tdd/services/build_relevance_test.dart`, and the marker pin
  in `test/core/dependencies/dependency_wirer_test.dart`.

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/build_relevance.dart
             lib/src/core/dependencies/dependency_wirer.dart
             test/plugins/tdd/services/build_relevance_test.dart
             test/core/dependencies/dependency_wirer_test.dart
→ No issues found!          (re-checked after dart format)

dart analyze            (whole repo)
→ 106 issues found      (0 errors, 0 warnings — all `info`)
```

Zero findings from the changed/new files; the whole-repo count is the
pre-existing info-level baseline drift (106 here, same order as the 106 the
#1636 verification recorded), not this change.

## 2. TDD discipline (REAL runs in this session)

- RED, pre-fix (verbatim in `.specify/bugs/1655-setup-build-yaml-static-
  skip-unreachable/red-evidence.md`):

```
dart test test/plugins/tdd/services/build_relevance_test.dart
→ 00:00 +30 -1: Some tests failed.
  U-1655-b1 Expected: 'refactor build pass skipped: build_runner has never
     run here …' (staticFirstBuildSkippedNote)
     Actual:   <null>        ← the gate ran the first build on a pristine
                               zfa setup build.yaml: the issue's bug
```

- GREEN, post-fix:

```
dart test test/plugins/tdd/services/build_relevance_test.dart
→ 00:00 +31: All tests passed!
```

The fix was applied only after the repro test was proven red; no test was
edited to make it pass retroactively. U-1655-b2/b3/b4/b5 (the guard tests)
passed both pre- and post-fix, proving the fix did not need them loosened.

## 3. Regression suites (REAL runs in this session)

```
dart test test/plugins/tdd/services/ test/core/dependencies/
→ 01:40 +1151: All tests passed!
   (includes refactor_passes_test.dart — the #1624/#1634 build-gate suites
   asserting staticFirstBuildSkippedNote — every step_runner/neighbor
   suite, and the dependency_wirer/build_yaml_guard/preflight suites)

dart test test/core/dependencies/dependency_wirer_test.dart
          test/commands/build_yaml_guard_test.dart
          test/commands/builder_dependency_preflight_test.dart
          test/plugins/tdd/services/refactor_passes_test.dart
→ 00:05 +45: All tests passed!
   (the three template consumers: setup's writer, the build guard, the
   YAML-parsing preflight — header addition proven safe for the parser)

dart test test/commands/build_command_unit_test.dart --preset=all
→ 00:19 +48: All tests passed!
   (slow tier — the build command writes the template; byte-identity
   between guard scaffold and const still holds)

dart test test/commands/
→ 06:11 +401: All tests passed!
```

Chunk/cache hygiene: `.dart_tool/test/` and `/tmp/dart_test.kernel.*` were
cleaned before and after the runs; disk stayed >80% free throughout.

## 4. Acceptance criteria audit (issue #1655)

1. **Fresh app's first refactor skips the build pass when no annotated
   files exist (even with build.yaml present)** — PROVED at the gate level:
   U-1655-b1 red pre-fix, green post-fix. The fixture is the reported app
   shape: setup's byte-exact build.yaml + plain Dart under lib/test, no
   `.dart_tool/build/`, zero annotations. Not proven by running a real
   `zfa tdd refactor` end-to-end (the fast-tier convention this repo pins
   for cloud agents; the gate IS the decision the refactor consults, via
   the unchanged binding refactor_passes_test.dart exercises).
2. **User-authored build.yaml still forces the build** — PROVED two ways:
   the pre-existing #1634 user-authored test (custom content) and the new
   MODIFIED-template test (single-byte divergence → run). Exact content
   match is deliberately strict; the skip is an optimization, the run is
   always sound.
3. **Entrypoint AOT compile eliminated or paid during setup** — PROVED for
   the static-skip half: with the note returned, the refactor records a
   synthetic skipped build action and never spawns `zfa build`, so
   `dart compile aot-snapshot` of build.dart is not reached on this path.
   (Not re-timed end-to-end; the #1634/#1655 measurements quantify the ~4
   min cost being avoided.)
4. **Existing incremental freshness logic unchanged** — PROVED by diff and
   by tests: zero hunks touch the marker-mtime path (rules 2–6), the
   asset-graph reader, or the build pass; the entire pre-existing #1624 /
   #1634 incremental suite ran green unchanged, and
   `staticFirstBuildSkippedNote`/`refactorBuildSkippedNote` are consumed by
   const reference (the #1655 note-text update flows through without
   behavior change).

## 5. Verdict

PASS — the bug is fixed at the gate level with red→green evidence, the
provenance contract between the template writer and the static skip is
pinned on both sides, the user-authored/user-edited run-direction is
pinned, and every touched package's fast tier (1552 tests total across the
sweeps) ran green in this session.
