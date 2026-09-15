# Cycle Log: 1634-fresh-app-first-build-skip

Append-only. One entry per TDD cycle (spec 046 / TDD extension v1.1.2).

## Cycle: T001 (red)

- behavior: S1, S2, S3, S4, S5, S6
- kind: red
- classification: compileError (the API under test does not exist yet)
- criterion: SC-1, SC-2, SC-3 (spec.md) — the static first-build decision
- test: `test/plugins/tdd/services/build_relevance_test.dart` — the
  #1624 missing-marker test REWRITTEN into the static matrix
  (`refactorBuildSkipNote — static first build (issue #1634)`: S1 skip
  shape, S2 annotation, S3 non-Dart, S4 build.yaml, S5 build-dir
  without marker, S6 error contract)
- command: `dart test test/plugins/tdd/services/build_relevance_test.dart`
- exit: 1
- at: 2026-09-15T14:55:00Z
- output:
```
00:00 +0: loading test/plugins/tdd/services/build_relevance_test.dart
00:00 +0 -1: loading test/plugins/tdd/services/build_relevance_test.dart [E]
  Failed to load "test/plugins/tdd/services/build_relevance_test.dart":
  test/plugins/tdd/services/build_relevance_test.dart:291:24: Error: Member not found: 'staticFirstBuildSkippedNote'.
          BuildRelevance.staticFirstBuildSkippedNote,
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```
- corroborating analyze (exact error inventory):
```
error - build_relevance_test.dart:291:24 - The getter
'staticFirstBuildSkippedNote' isn't defined for the type
'BuildRelevance'. ... - undefined_getter
1 issue found.
```
- reading: the gate's static branch and its note constant do not exist
  at HEAD (2ac6b9d7 + spec artifacts) — `refactorBuildSkipNote` still
  fails open on the missing marker (the exact #1634 shape: the S2/S3/S4
  fixtures would pass today, but S1's fresh-calculator fixture is
  asserted against an undefined constant, so the file cannot even load).
  The red is the intended undefined-API red; no parser noise.

## Cycle: T002 (green)

- behavior: S1, S2, S3, S4, S5, S6
- kind: green
- classification: pass
- criterion: SC-1, SC-2, SC-3 (spec.md)
- change: `lib/src/plugins/tdd/services/build_relevance.dart` ONLY —
  `staticFirstBuildSkippedNote` constant + `_staticFirstBuildSkipNote`
  private static scan + the `refactorBuildSkipNote` branch (marker
  missing AND `.dart_tool/build/` absent → static scan; directory
  present without marker → null). The incremental path below the
  marker check is byte-identical to #1624.
- in-cycle honesty note: the FIRST green run failed S6 — the static
  call was `return _staticFirstBuildSkipNote(...)` WITHOUT `await`, so
  the static scan's decode error bypassed the caller's `try/catch` and
  escaped the gate as a `FileSystemException` (a bare `return future`
  hands the future's error straight to the caller). Fixed with a
  load-bearing `await` + comment. No test edited in this fix. The S6
  red-then-caught sequence is exactly the error-contract behavior the
  test exists to pin.
- command: `dart test test/plugins/tdd/services/build_relevance_test.dart test/plugins/tdd/services/refactor_passes_test.dart`
- exit: 0
- at: 2026-09-15T15:20:00Z
- output:
```
00:05 +39: All tests passed!
```

## Cycle: T003 (green — registry binding + mechanical seam updates)

- behavior: S1b (+ mechanical tests U1–U5, misfire-stop, #717 PATH)
- kind: green
- classification: pass
- criterion: SC-1 (FR-7 — recording shape unchanged), no-regression on
  registry mechanics
- change: `test/plugins/tdd/services/refactor_passes_test.dart` —
  (a) the #1624 binding test's first assertion flips from `isNull` to
  `staticFirstBuildSkippedNote`: the empty scratch project IS the US1
  fresh-app shape, so through the REAL bound gate it now proves the
  static skip end-to-end at the registry seam; (b) the seven MECHANICS
  tests (U1 order, U2 action capture, U3 misfire-stop, U4 empty diff,
  U5 snapshot diff, does-not-start misfire-stop, bug #717 PATH
  execution) pass `buildSkipGate: () async => null` — the constructor's
  existing test seam — because their subject is the pass registry, not
  gating, and on a nothing-builder-facing scratch the new gate would
  now (correctly) suppress the build pass they need to observe. Each
  carries an issue-naming comment so the seam is never mistaken for a
  gate bypass in production code.
- command: `dart test test/plugins/tdd/services/refactor_passes_test.dart`
- exit: 0
- at: 2026-09-15T15:22:00Z
- output:
```
00:05 +39: All tests passed!   (26 build_relevance + 13 refactor_passes)
```

## Cycle: T004 (pin — incremental path byte-identical, green-before-write)

- behavior: P1, P2
- kind: pin (NOT a red — declared, per the 1505 honesty convention)
- classification: pass
- criterion: SC-4 (spec.md) — FR-5 hard constraint
- test: `test/plugins/tdd/services/build_relevance_test.dart` groups
  `refactorBuildSkipNote (issue #1624)` (five writeMarker-based tests)
  + `canSkipTerminalBuild` + `fingerprint` groups — source UNCHANGED
  from base 2ac6b9d7 (proven: the incremental section extracted from
  the red-phase commit diffs empty against this implementation).
- command: `dart test test/plugins/tdd/services/build_relevance_test.dart`
- exit: 0
- at: 2026-09-15T15:24:00Z
- output:
```
00:00 +26: All tests passed!   (within the +39 combined run above)
```
- reading: every #1624 incremental verdict (newer annotated/plain/
  non-Dart/config, unchanged tree) and every #1587 make-gate test pass
  byte-identical — the first-build decision is the only behavior this
  issue changed.
