# Fix report — Issue #1470

Branch: `fix/1470-artifacts-json-corruption-silent` (one PR, closes #1470).
TDD mode: red → green recorded in `red-evidence.md` / `test.md`, and in
`../../tdd/verification.md`.

## What changed and why

1. **`lib/src/plugins/tdd/services/artifact_registry.dart` — the
   corruption gate in `_loadRecords`.**

   New exception, mirroring `RunStateCorruptException`'s contract (message
   field, `toString() => message`):

   ```dart
   /// Raised when `tdd/artifacts.json` exists but cannot be parsed (bug
   /// #1470). Corruption must never be conflated with an empty registry: ...
   class ArtifactRegistryCorruptException implements Exception {
     const ArtifactRegistryCorruptException(this.message);
     final String message;
     @override
     String toString() => message;
   }
   ```

   `_loadRecords`' swallow replaced with one gate for every wrong shape —
   unparseable JSON, a non-object top level, a missing/non-list "records",
   and non-object record entries (the last three previously read as `[]`
   or leaked a raw `TypeError`; closed in the review-fix round):

   ```dart
   Never corrupt(String cause) => throw ArtifactRegistryCorruptException(
     'corrupted artifacts.json at $registryPath ($cause). Recovery: '
     'repair the file to valid registry JSON '
     '(a "feature" plus a "records" list) or restore it from version '
     'control — do NOT delete it, or the next gen re-registers every '
     'behavior as created and can duplicate artifact files.',
   );
   ...
   } on FormatException catch (e) {
     corrupt('invalid JSON: ${e.message}');
   }
   ```

   The message names the file (absolute registry path), the parser cause,
   and the recovery path. Recovery prescribes repair/restore rather than
   the issue's suggested "delete and re-run gen": with surviving artifact
   files on disk, deletion + re-gen is precisely the duplicate-file symptom
   the issue reports. The thrown contract (type, file, cause, actionable
   recovery) matches the issue's request.

2. **Nothing else in lib/.** `git diff --stat` vs the branch point = one
   lib file (+32/−15: the exception class + the `_loadRecords` gate and
   comments, the review round accounting for +17 of it).
   Deliberately untouched: `RunStateStore.readDropped`'s intentional
   `FormatException → const []` (documented: `load()` is the corruption
   gate that fires first), FR-012 missing-file
   semantics (unchanged, now pinned by a test), and every caller
   (`doctor`, `migrate-paths`, `gen`, `verify`, ... — they surface the
   exception naturally, exactly like an uncaught `RunStateCorruptException`
   would outside doctor's own wrapper).

## Constraints honored

- Fix broadly confined to the `_loadRecords` gate in
  `artifact_registry.dart` — yes; the lib/ diff is the exception class +
  the gate (+ comments). The review-fix round widened the gate from the
  `FormatException` clause to every wrong shape, per the reviewer findings
  (the original constraint's "FormatException only" reading was superseded
  by the review).
- `dart analyze` no new warnings — yes: changed files analyze clean; whole
  repo 112 issues (all `info`) on the branch vs 112 on the pre-change
  baseline, 0 errors/warnings both sides.
- Related `run_state_store.dart` validation approach mirrored — yes: same
  exception shape, same "names the file + recovery path" message discipline.

## Verification (all run on this branch, Dart 3.13.3)

- RED: probe RED-1/2/3 + compile-level RED (`red-evidence.md`).
- GREEN: the new suite 5/5; registry-adjacent suites (artifact_registry,
  bug_1357 reanchor, mutation scope/auditor, spec fuzz auditor, behavior
  kind trace) 68/68; chunked fast-suite sweep across all 103 runnable
  chunks + 4 root-file chunks (incl. 905 tests in tdd/services and 519 in
  tdd root) — zero genuine failures; 5 folders correctly SKIP (all
  slow-tier-tagged, per dart_test.yaml policy); whole-repo analyze 112 =
  baseline; `dart format` clean on both changed files.
- Full numbers and commands: `../../tdd/verification.md`.

## Review-fix round (2026-09-13, zuraffa-review findings 1–3)

- Gate widened to every wrong shape (findings 1–2) and the U-1470-a2
  fixture now truncates the real seeded registry bytes instead of an
  unrelated literal (finding 3).
- Review-round RED for the two new pins (gate not yet added): filtered run
  of the new suite → `+0 -2` (old behavior: silent `[]`, raw `TypeError`).
- Review-round GREEN: new suite 7/7; registry-adjacent command 70/70;
  `dart analyze` changed files clean; `dart format lib test` 0 files
  changed; `test/plugins/tdd/services/` folder run green.
