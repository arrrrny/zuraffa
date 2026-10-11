# TDD Verification — feature `1193-realize-mocked-to-real-swap`

Written from the ACTUAL runs performed on this branch (every command below
was executed; outputs are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.3 (stable) on linux_x64 (`dart --version`). Flutter is
not installed in this environment — the pure-Dart CLI lanes and the fast
suite run without it; the `example/` sub-package (Flutter) is out of scope
and was not resolved (`dart pub get` resolves the root package; the example
workspace is skipped exactly as on CI).

## Gate

- gate: `passed`
- analyze (changed files only):
  `dart analyze lib/src/plugins/tdd/commands/realize_command.dart
  lib/src/plugins/tdd/services/adapter_scaffolder.dart
  lib/src/plugins/tdd/services/realize_receipt.dart
  test/plugins/tdd/commands/realize_command_1193_test.dart`
  → **No issues found!**
- targeted suite (the surfaces this spec touches — the new 1193
  acceptances plus every pre-existing realize surface, the realize
  registration/verdict paths, and the service seams reused):
  ```
  dart test test/plugins/tdd/commands/realize_command_1193_test.dart \
            test/plugins/tdd/commands/realize_command_test.dart \
            test/plugins/tdd/commands/realize_diff_only_test.dart \
            test/plugins/tdd/json_flag_test.dart \
            test/plugins/tdd/bug_969_json_verdict_envelope_test.dart \
            test/plugins/tdd/services/realize_state_test.dart \
            test/plugins/tdd/services/differential_harness_test.dart
  → 00:12 +82: All tests passed!
  ```
  (10 new 1193 acceptances + 9 spec-913 realize acceptances + 3
  spec-1195 diff-only acceptances + realize-flag/verdict-envelope
  registrations + realize-state/differential-harness service suites.)
- neighbors: `test/plugins/tdd/services/journal_test.dart` (the #1113
  writer this spec appends through) → **34/34 passed**; the ci_referee
  provenance surfaces were read, not modified.
- format: `dart format` over the four changed files → second pass
  **(0 changed)**.
- kernel cache cleaned per protocol (`rm -rf .dart_tool/test/`,
  `rm -f $TMPDIR/dart_test.kernel.*`) before and after the runs.

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree)

`dart test test/plugins/tdd/commands/realize_command_1193_test.dart`:

```
00:03 +0 -10: Some tests failed.

Failing tests (10/10 — the pre-change tree cannot satisfy any of them):
  CERT-1 / CERT-2 (no certified-mock lookup — CERT-2's transcript shows
    the swap PROCEEDING to result=realized on an unsatisfied mock-cert)
  DRY-1 / DRY-2 / DRY-3 ("Could not find an option named \"--dry-run\".")
  JRN-1 / JRN-2 (no tdd/journal.json append, no mocked->done advance)
  RCPT-1 (no realize-receipt.v1 hand-delta receipt)
  SCAF-1 / SCAF-2 ("--scaffold" unknown; refusal does not name the seam)
```

Full transcript: `tdd/red-evidence.txt`.

### GREEN (the same 10 acceptances on the change)

```
00:00 +1: DRY-2: --dry-run and --diff-only are mutually exclusive
00:01 +3: SCAF-1: --scaffold scaffolds the real adapter behind the SAME interface...
00:01 +5: JRN-1: a realized swap appends the unified journal entry...
00:02 +7: RCPT-1: the swap writes realize-receipt.json...
00:03 +9: CERT-2: a RED certification blocks the swap...
00:03 +10: All tests passed!
```

No regressions: the pre-existing realize suites (spec 913 + spec 1195)
pass UNCHANGED on the same tree (12/12 within the 82-test targeted run).

## What was built (files)

- `lib/src/plugins/tdd/services/adapter_scaffolder.dart` (new) — the
  `--scaffold` hand-delta seam: same-interface extraction from the
  certified mock's own declaration, fail-closed member parsing,
  re-scaffold never clobbers, `write: false` validation mode for the
  dry-run preview.
- `lib/src/plugins/tdd/services/realize_receipt.dart` (new) — the
  `realize-receipt.v1` hand-delta receipt: files + digests + buckets +
  gate outcomes + generated/mock/hand ratios (`G%/M%/H%`), atomic write.
- `lib/src/plugins/tdd/commands/realize_command.dart` — the spec 1193
  flow: `--dry-run`, `--scaffold`, the #1110 certified-mock location
  (red blocks, missing is named), the journal advance (behaviors
  `mocked → done` in run-state.json + the schema-valid meta entry in
  tdd/journal.json), the realize receipt, and the extended
  machine-readable summary (`mocks=c/t`, `scaffold=<file|->`).
- `test/plugins/tdd/commands/realize_command_1193_test.dart` (new) — the
  10 acceptances driving the command in-process (injected suite runner +
  fixture driver, the house pattern).
- `specs/1193-realize-mocked-to-real-swap/` — this spec, the test list,
  the red evidence.

## Honest scope notes

- The `specify` CLI (uv/spec-kit) was NOT re-run: the repo already
  carries `.specify/` (templates, scripts, memory) and the standing
  warning forbids clobbering an existing `.specify/templates` or
  `.specify/scripts`; this verification.md follows the house format of
  the merged spec folders (e.g. 1195).
- The full-repo fast tier was not re-run end-to-end in this environment;
  the task protocol scoped verification to the changed surfaces plus
  their nearest consumers (all listed above, all green). `dart analyze`
  on the changed files reports zero issues.
- Success criteria SC-1..SC-5 are PROVED by the tests named in
  `tdd/test-list.md` (all `done`). Nothing in this file claims a run
  that did not happen.
