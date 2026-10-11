**Template Version**: `zuraffa-1.0`

# Plan: 1329-failed-step-zero-diagnostics

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.11.0); no Flutter SDK
  dependency on this package's own test path.
- **Feature surface** (recording layer only — issue #1329 hard constraint:
  the core engine cycle, the gen/make/compose/view implementations, the
  refactor pass, and the verify gate are untouched; no step timeout or
  retry changes):
  - `lib/src/plugins/tdd/services/step_runner.dart` — `StepResult` ADDS:
    the spawned `command` line (the argv the runner actually executed,
    joined for display), captured once where the argv is built and carried
    by every construction site (success, spawn-failure, and timeout
    results alike). The driver needs the real command for FR-001's
    `- command:` evidence; reconstructing it in the driver would duplicate
    the argv assembly (baseline handoff flag, timeout flag, `.dart`
    entrypoint prefix) and drift.
  - `lib/src/plugins/tdd/models/cycle_entry.dart` — `CycleEntryKind` ADDS:
    the `error` kind (red/green/refactor stay byte-compatible, U10). The
    existing assert (`red` entries must classify) is untouched — `error`
    entries may omit the classification like green/refactor entries. The
    model ADDS an optional `outcome` field rendered as an `- outcome:`
    line only when set (the `- evidence:`/`- subject-hash:` additive
    precedents), so the entry names the step's own failure token without
    overloading `classification`.
  - `lib/src/plugins/tdd/services/journal.dart` — `JournalEntry` ADDS: the
    optional structured `error` object (`JournalStepError`: behavior,
    step, outcome, exit_code, command, output) with `toJson`/`fromJson`
    support; `_entrySchema()` and `validateEntry` declare/validate the new
    optional property (the schema is GENERATED from the model, so writer
    and shipped schema cannot drift — the #1111 discipline). `JournalStepError`
    is a new public model class beside `JournalEntry`.
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` — the two-cycle
    driver (`RunDriverCore`). `_driveBehavior`'s honest-stop arm ADDS: the
    failure-detail capture (a `_StepFailure` record: behavior, step,
    outcome, exit code, command, truncated output tail) + the cycle-log
    `error` entry append (never a gate — a failed append is reported, not
    fatal) before the existing stop return. The pre-spawn `StateError`
    arm records the same shape with `outcome=runner-error`, exit -1, the
    resolution error message as output, and no spawned command. A private
    instance field (`_lastStepFailure`, the established
    drive-is-non-reentrant pattern the stream context uses) carries the
    detail from the failure arms to `_finish`, which appends the journal
    error object + the `step_error=` violations line to the lane entry.

## Key decisions

- **D1 — the error entry is a NEW cycle kind, never `red`.** `red` is
  CERTIFIED red evidence: an `error` entry under `kind: red` would flip
  the behavior's reconciled state to red on retry (bootstrappable pending
  → red) and re-drive it from `make`, skipping gen/verify-red — wrong for
  a gen failure, and exactly the phantom-evidence family #1264 fixed. The
  `error` kind parses as an ordinary entry (kind is a free token in
  `parseEntries`), matches none of the evidence sets (`redEvidence` /
  `greenEvidence` / `refactorEvidence` stay keyed on their own kinds), so
  reconciliation is untouched and FR-003's "retry re-drives the failed
  step" holds by construction.
- **D2 — the evidence shape is the EXISTING one, extended additively.**
  The entry renders through the unchanged `CycleLogEntry.toMarkdown`
  pipeline (behavior/kind/classification/criterion/test/command/exit/at/
  output + the schema-1 chain lines). Additions are optional lines that
  only render when set (`- outcome:`), outside the chain-hash payload
  like the `- evidence:` and `- subject-hash:` precedents, so the evidence
  schema stays v1 and legacy parsers keep working.
- **D3 — the spawned command is captured at the source.** `StepResult`
  gains the joined argv actually spawned (including the baseline and
  timeout flags and the `dart <entry>` prefix); the driver records what
  ran, not a reconstruction. For the pre-spawn arm there is no command —
  the recorded value says so, and the resolution error message is the
  captured output (FR-004).
- **D4 — truncation keeps the TAIL (200 lines) with a marker.** Step
  failures end in the error (stack traces, the failing summary line); the
  head is the least diagnostic part. The marker line names how many lines
  were dropped so the evidence stays honest about what it dropped. One
  shared truncation helper produces the SAME tail for the cycle-log block
  and the journal `error.output` (one truncation, two consistent views).
- **D5 — the failure detail flows to the journal via the instance
  field, not a wider stop tuple.** `_Stop`/`_DriveResult` records are
  constructed at ~15 sites (every named stop arm + the phase-0 entity
  arms); widening the tuple would touch every arm the issue forbids
  changing. The driver already relies on per-invocation instance state
  for the stream context (drive is non-reentrant per instance); the
  failure detail uses the same pattern: reset at `drive()` start, set by
  the failure arms, consumed by `_finish` for the lane journal entry.
- **D6 — the journal error is a structured object + a scan line.** The
  violations array stays stringly (schema-compatible); the machine detail
  lives in the new optional `error` object the generated schema declares.
  Downstream readers (`JournalReader` consumers: status, theater, prove)
  parse via `JournalEntry.fromJson`, which ignores unknown keys — the
  additive field cannot break them, and `validateEntry` gains the
  property check so written journals validate against the shipped schema.

## Risks / notes

- The fake-zfa slow-tier driver tests script failures through the
  fixture's config files; the fixture's fake gains one ADDITIVE gen
  outcome token (`flood`) that prints >200 noise lines so the truncation
  contract is provable end-to-end. Existing outcome tokens and configs
  are untouched.
- Error entries participate in the per-behavior hash chain (they are
  ordinary schema-1 entries): a later red/green/refactor entry chains
  from the error entry's hash — `lastHashFor` is kind-agnostic, the
  doctor recomputes from parsed fields, and `error` parses as a plain
  kind token. No chain change needed.
- `dart test` defaults to the fast tier (`exclude_tags: slow`); the new
  driver-level suite carries `@Tags(['slow'])` like `run_command_test.dart`
  and is run explicitly.
- Disk hygiene: the driver suites spawn `dart pub get`/`dart test` in
  temp fixtures; the kernel cache is cleaned before and after the targeted
  runs (`.dart_tool/test/`, `$TMPDIR/dart_test.kernel.*`).
