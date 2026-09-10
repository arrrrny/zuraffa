**Template Version**: `zuraffa-1.0`

# Plan: 1391-realize-mock-skip-foreign-fixtures

## Technical Context

- **Language/stack**: Dart 3.13 (SDK ^3.11.0), pure-Dart package; test
  runner `dart test`; static analysis `dart analyze`.
- **Command surface**: `zfa tdd realize-mock <entity> --against=firestore`
  — `lib/src/plugins/tdd/commands/realize_mock_command.dart`, the fixture
  scan loop (currently lines ~336-373) between the tier-1 contract-test
  run and the per-method differential.
- **Document shapes in `specs/<feature>/tdd/fixtures/`**:
  - `realize-diff.v1` contract case: `{"schema": "realize-diff.v1",
    "id": ..., "input": {"op": ...}, "mockOutput"?: ..., "seed"?: ...}`
    (written by the #1367 mock-cert fallback synthesis at
    `realize_mock_command.dart:664` and by every committed test helper).
  - #832 `manifest.json` (issue #832/#1001): `{"schema": 1, "bug": 832,
    "families": [...], "files": {...}, "digest": "..."}` — written by
    `lib/src/simulation/fixture_registry.dart:writeManifest`.
  - #832/#1001 `mock-cert.<Entity>.json`: `{"schema": 1, "spec": 1001,
    "entity": ..., "methods": [...], ...}` — written by
    `lib/src/plugins/mock/certification/mock_cert_receipt.dart:toJson`.
- **Crash mechanics**: the scan ingests every `.json` file, then fails
  closed (`RealizeMockOutcome.runnerError`, exit 1) when the decoded
  document has no `input` map — exactly the shape of both registry
  files. The three real cases run first (sorted), then the crash fires
  on the first foreign file — the issue #1391 signature
  (`methods=3 mismatch=0 result=runner-error`).
- **Coexistence precedent**: the repo's own `specs/*/tdd/fixtures/`
  directories already hold `manifest.json` + world/golden JSONs beside
  contract artifacts — the collision is the designed end-state of #1001
  x #1009, not an accident.

## Design Decisions

1. **Classify by schema, not by filename** (FR-001): a document is a
   contract case iff it decodes to a JSON object whose `schema` equals
   the exact string `realize-diff.v1`. Filename patterns
   (`manifest.json`, `mock-cert.*.json`) are covered behaviorally — both
   carry `schema: 1` — so a renamed or new registry file is skipped
   without a pattern-listing chase (FR-003). The issue's "better"
   remediation (parse-first, skip non-`realize-diff.v1`, log) is
   implemented verbatim; the "at minimum" filename ignore-list is
   subsumed.
2. **Skip is visible, never silent** (FR-002): each skipped document
   prints `skipped <name> (schema <x>)` at the same indentation as the
   per-method lines (`   skipped manifest.json (schema 1)`). `<x>` is
   the schema value rendered verbatim (`1` for the #832 artifacts, the
   string verbatim, `unknown` when absent or the file is unparseable)
   via a total, non-throwing renderer.
3. **Fail-closed preserved for the gate's own schema** (FR-004): a
   document stamped `realize-diff.v1` that lacks `input` or `input.op`
   keeps the existing hard validation ("fix the fixture before
   certifying" / "carries no input.op") with outcome `runner-error`.
   Skipping is for foreign documents only — a broken own-schema case
   must never silently shrink the certified surface.
4. **Empty-after-skip fails BLOCKED, not certified** (FR-005): if every
   scanned document was skipped, the gate fails with
   `RealizeMockOutcome.blocked` and a message naming the skip — the
   "an empty surface is never certified" contract (the pre-scan
   `fixtureFiles.isEmpty` check) extends past the new filter. This also
   removes the crash path's `runner-error` outcome from the foreign-only
   scenario.
5. **Receipt and evidence formats unchanged** (FR-006, FR-007): skipped
   files surface through the log line only; the receipt document, the
   summary line (`methods= mismatch= result=`), and the era-tagged
   cycle-log entry keep their exact formats — no downstream parser
   drift.
6. **Single-file diff**: all production changes live in
   `realize_mock_command.dart`'s scan loop (the early-shape validation
   becomes schema classification + skip, then the existing `input`/`op`
   validation for own-schema documents, then a post-scan
   zero-cases-blocked guard). No engine, certify, or schema changes.

## Risk Assessment

- **Backward compat (AC-4)**: all in-repo writers stamp
  `schema: "realize-diff.v1"`, so schema-required classification cannot
  strand a legitimate committed case; a schema-less but otherwise valid
  document is skipped visibly (`schema unknown`) and a foreign-only
  directory fails BLOCKED naming the skip — discoverable, honest.
- **Verdict honesty**: the skip path adds no records; the per-entity
  gate (`mismatches.isEmpty`) and receipt writer are untouched.
- **Rollback**: single-file production diff, feature-flag-free.

## Implementation Notes

- The renderer for `<x>`: JSON-encode the schema value (safe on decoded
  JSON), cap the length, `unknown` for null/absent — total function, no
  throw paths.
- The skip log uses the file basename WITH extension (`manifest.json`,
  not `manifest`) — the name a user sees in the directory.
- Tests inject the tier-1 suite runner and tier-2 provider factory (the
  established `realize_mock_command_test.dart` pattern); no process
  spawns in tests.
