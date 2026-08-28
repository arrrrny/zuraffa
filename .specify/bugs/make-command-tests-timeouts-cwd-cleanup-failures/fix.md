# Fix — make-command tests: timeouts + CWD cleanup failures

- **Slug**: make-command-tests-timeouts-cwd-cleanup-failures
- **Status**: resolved (test infrastructure fix)
- **Date**: 2026-08-28
- **Verdict**: valid
- **Triage**: issue #503

## Root cause

Two heavy `MakeCommand` integration tests in `test/commands/make_command_test.dart`
time out / fail during cleanup:

- `#346 — with di --use-mock registers the mock datasource`
- `#412 — full plugin bundle (repository usecase di mock provider service datasource)`

They drive `zfa make` as a subprocess that generates a full plugin bundle for a
temp project (including `dart pub add` / generation). The original
`timeout: const Timeout(Duration(minutes: 2))` was too tight for the real
generation cost in CI, and the `MakeCommand` / `MakeCommand #508` groups'
`tearDown` deleted the workspace without tolerating `PathNotFoundException`, so
when a still-running child subprocess (or the in-process CLI runner still
resolving its CWD) held the deleted directory, cleanup threw.

## Remediation

1. Raised every `Duration(minutes: 2)` test timeout in the file to
   `Duration(minutes: 5)` so the full-bundle generation completes.
2. Hardened `tearDown` in the `MakeCommand` and `MakeCommand #508 id-neutral
   regeneration` groups to wrap `workspace.delete(recursive: true)` in
   `try { ... } on PathNotFoundException { ... }`, matching the already-robust
   `MakeCommand #307 identity contract` group. The workspace is still restored
   to a valid CWD before deletion.

No production code changed — this is purely test-infrastructure hardening,
consistent with the bug being a test-infrastructure problem.

## Files changed

- `test/commands/make_command_test.dart` — timeouts 2→5 min; `tearDown` CWD-cleanup
  hardened in two groups.

## Verification

- `#412 — full plugin bundle ...` passes (ran in ~30s under the 5-min budget).
- `#346 — with di --use-mock registers the mock datasource` passes.
- `dart analyze test/commands/make_command_test.dart` clean.
