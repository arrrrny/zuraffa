**Template Version**: `zuraffa-1.0`

# Plan: 1308-tdd-run-vacuous-guard-remedy

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.11.0); no Flutter SDK
  dependency on this package's own test path.
- **Feature surface** (all messaging/warning layer — issue #1308 hard
  constraint: the engine cycle, verify gate semantics, and contract scanner
  are untouched):
  - `lib/src/plugins/tdd/services/vacuous_guard.dart` — the messaging
    vocabulary: the machine-readable `vacuousGuardMarker`
    (`zfa:tdd: vacuous-guard`, issue #1259), the vacuous-green detector
    `contentIsVacuousGreen`. ADDS: the exact fallback remedy string, the
    guard-only warning token the run driver greps for, the hand-step
    journal line builder, and a marker-presence predicate.
  - `lib/src/plugins/tdd/services/behavior_test_writer.dart` — `_deriveAssertion`
    falls through to the bare guard when `contractShape == null` (fallback
    routing: no `traces:` line resolves) and the prose heuristics
    (`returns N` / `throws X`) do not match; `_declaredAssertion` emits the
    guard WITH `vacuousGuardMarker` for entity/void traced returns. ADDS:
    the gen-time guard-only warning (printed by the writer after it writes
    a fallback guard-only unit test; the test file is still written).
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` — the two-cycle
    driver (`RunDriverCore`). `_driveBehavior`'s honest-stop block prints
    the generic `step failed — behavior=<id> step=make outcome=...` +
    `resume:` lines; `_finish` writes the lane receipt and the journal
    entry (`stopped_at`, violations). ADDS: (1) the vacuous-green stop arm
    distinguishing the fallback path (marker absent → FR-001 remedy,
    `stopped_at=<id>:make`) from the traced entity/void path (marker
    present → named hand step `stopped_at=<id>:hand`, guidance naming what
    to write and where); (2) `_finish` carries a hand-step violation into
    the journal entry when the stop is the hand seam; (3) forwarding of the
    gen child's guard-only warning lines into the run transcript.

## Key decisions

- **D1 — the driver distinguishes the two vacuous paths by the MARKER, not
  by re-parsing the spec.** The generated test file is the single source of
  truth: the traced entity/void path is the ONLY writer path that emits
  `zfa:tdd: vacuous-guard`; the fallback path emits the bare guard without
  it. Reading the generated test (namespaced `test/tdd/<feature>/<snake>_test.dart`
  with the legacy flat fallback, the same resolution `_hasPendingWithArtifacts`
  already uses) keeps the contract scanner and the routing resolver
  untouched.
- **D2 — the machine contract is preserved where the issue preserves it and
  replaced where it demands replacement.** The summary line stays
  `stopped_at=<behavior>:<step>`-shaped; for the traced path the step token
  is the named hand step (`<id>:hand`) — exactly the issue's "instead of the
  generic stopped_at=<id>:make". Downstream consumers parse `stopped_at` as
  a string and split on the last colon (corpus ledger), so the token is
  additive, not breaking.
- **D3 — the gen warning prints from the writer and is FORWARDED by the
  driver.** The writer owns the vocabulary (it knows contractShape and the
  derived assertion); gen's stdout is captured by the driver's StepRunner
  and NOT printed on success today, so the driver greps the captured output
  for the warning token and echoes the lines. Standalone `zfa tdd gen`
  runs see the warning directly.
- **D4 — the remedy string is a shared constant** (`vacuous_guard.dart`)
  consumed by the writer's warning and the driver's stop message: one
  source, no drift (FR-005).

## Risks / notes

- The fake-zfa slow-tier driver tests need the marker-carrying test file
  seeded on disk before the run (the fake gen does not write files); the
  fixture's `seedTestList` + a direct file write cover it.
- `dart test` defaults to the fast tier (`exclude_tags: slow`); the new
  driver-level suite carries `@Tags(['slow'])` like
  `run_command_test.dart` and is run explicitly.
