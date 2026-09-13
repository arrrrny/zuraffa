# Bug Fix: artifacts.json silently swallows corruption

- **Slug**: 1470-artifacts-json-corruption-silent
- **Fixed**: 2026-09-13
- **Assessment**: ./assessment.md
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1470
- **Change type**: bug fix (defensive error handling, one store, one clause)

## What changed

Two files, both in the TDD plugin's registry unit:

1. `lib/src/plugins/tdd/services/artifact_registry.dart`
   - New `ArtifactRegistryCorruptException` (same shape as
     `RunStateCorruptException`: a `message` field and
     `toString() => message`), documented with the reason a corrupt
     registry must never read as "fresh feature".
   - `_loadRecords()`'s `on FormatException` clause now rethrows as
     `ArtifactRegistryCorruptException('Corrupt artifacts.json at
     $registryPath: ${e.message}. Delete the file and re-run gen to
     rebuild the registry.')` instead of `return []`. The exists() guard
     above it is untouched, so a MISSING registry file still returns the
     legitimate empty list (FR-012).
2. `test/plugins/tdd/services/artifact_registry_test.dart` — new group
   "corrupt registry (issue #1470)": 5 tests (4 behavioral + the FR-012
   guard) pinning loud failure for `loadAll`/`findRecord`/`register` on a
   truncated/garbage registry, the recovery-path wording of the message,
   and the untouched missing-file contract.

## Why this is the minimal change

The swallow lived in exactly one clause (`on FormatException { return [];
}`); every registry reader and writer funnels through `_loadRecords()`,
so rethrowing there fixes `loadAll`, `findRecord`, `preflight`,
`register`, `append` and `_appendRecord` in one move with no call-site
changes. The exception is additive: no ownership model, registry format,
or state-machine code changed (the hard constraints from the issue).
`RunStateStore`, `GapLedgerStore`, `CorpusManifestStore` and
`CorpusProgressStore` already fail loud on corrupt state; this closes the
last silent store in the TDD plugin, which is also what the issue's
suggested patch does verbatim.

Blast-radius note: commands that READ the registry (verify/run/doctor/
realize/compose/wire/…) now surface the corruption instead of silently
reporting an empty feature. That behavior change is the point of the P1
fix and matches the established store contract; the chunked fast-suite
sweep (99 passed / 0 failed) confirms no fixture or caller relied on the
swallow.

## Evidence

- RED (throw not yet wired): `dart test
  test/plugins/tdd/services/artifact_registry_test.dart` → `+15 -4`; the
  four corrupt-registry tests failed with the bug's own symptoms (silent
  `[]`, silent `null`, silent `Ownership.created/created`). Scratch repro
  on unmodified master additionally demonstrated the P1 data-loss chain
  (corrupt file → `[]` → re-register → registry rewritten to a single
  record).
- GREEN: same command → `+20: All tests passed!` (15 pre-existing + 5
  new), re-confirmed after `dart format .`.
- Neighbors: `dart test test/plugins/tdd/services/` → +950 pass;
  `test/plugins/tdd/commands/` → +533 pass.
- `dart analyze` (changed files) → No issues found!; full project → 112
  info lints, 0 errors / 0 warnings, identical to the stashed-fix
  baseline (112).
- Chunked fast suite → 99 passed / 5 pre-existing SKIP / 0 failed across
  all 104 chunks (see `tdd/verification.md`).
- `dart format .` → clean (only the new test file needed joining).
