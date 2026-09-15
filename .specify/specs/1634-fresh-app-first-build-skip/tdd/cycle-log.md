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
