# Plan — Spec 1331: reset deletes all owned files; make adopts re-driven subjects; doctor prescription matches reality

GitHub issue: arrrrny/zuraffa#1331

## Technical Context

Dart 3.13+ CLI (`bin/zfa.dart`, package `zuraffa`). The TDD plugin lives
under `lib/src/plugins/tdd/`. The four surfaces this spec touches:

### 1. `lib/src/plugins/tdd/commands/reset_command.dart` (owned-file deletion + validation)

Current defects, traced:

- `ownedExisting` is built from `record.testPath` / `record.subjectPath`
  RAW: `File(path).existsSync()` resolves a RELATIVE recorded path
  against the process CWD, and an ABSOLUTE path recorded by another
  checkout/worktree (gen's default is absolute — spec 1312) never
  matches the current tree. Drifted files are silently classified
  foreign and kept while their records are dropped — the half-state.
- `_countForeignGeneratedFiles` scans only the FLAT `test/tdd` and
  `lib/tdd` directories, non-recursively; the namespaced layout
  (`test/tdd/<feature>/…`, post-#827) is invisible to the foreign count.
- No warning when a record's paths did not exist; no post-deletion
  validation; the verdict carries no drift detail.

Fix design:

- Normalize every recorded path with `normalizeArtifactPath(cwd, path)`
  (`services/cross_feature_ownership.dart`, the same helper doctor and
  gen already use — #912/#1312 class) before the existence check.
- Add a recursive generated-layout scan (`test/tdd`, `lib/tdd`)
  collecting generated-shape files
  (`matchesGeneratedTestShape` / `matchesGeneratedSubjectShape` from
  `services/generated_shape.dart`) whose provenance header
  (`behaviorIdFromContent`) names one of the DROPPED behavior ids. These
  are owned-by-drift candidates: deleted even though their recorded path
  did not match. Safety: consult `foreignOwnerOf` first — a file another
  feature's LIVE registry owns is foreign-owned (kept, reported by
  name), never deleted.
- Report, before acting: the drift warnings (per dropped record whose
  normalized recorded path does not exist), the foreign-but-owned-looking
  files by name, and the unified will-delete list.
- After acting: re-stat every planned deletion, prove zero survivors,
  and emit the machine-verdict details `path_drift`,
  `foreign_owned_looking`, `deleted_files` (plus the existing
  `dropped_records` / `foreign_files_kept`).

### 2. `lib/src/plugins/tdd/models/generation_plan.dart` + `commands/make_command.dart` (the `adopted` outcome)

- New `MakeOutcome.adopted('adopted')`: the target test already passes
  against a subject whose prior certification the last reset tombstone
  invalidated — the re-drive class adopts the passing subject, certifies
  green, appends green evidence binding the CURRENT subject hash, exits
  0.
- Make's `alreadyGreen` branch gains the class probe:
  `JournalReader.lastResetTombstone(featureDir)` (new API returning the
  last tombstone's behavior ids + timestamp). Adoption fires iff
  `record.behaviorId` is tombstoned AND the last green entry for the
  behavior is absent or its `- at:` timestamp PREDATES the tombstone's.
  Timestamps that fail to parse fail CLOSED (the refusal stands) — the
  house safe-failure rule.
- In the adoption path the `_subjectDriftRefusal` probe is not consulted
  (its certified-hash basis is the invalidated evidence); the adoption
  note names the tombstone and the `adopted` outcome. The green evidence
  append is shared with the skip path (`subjectHash` is already
  recorded there), so post-adoption drift still refuses.
- All non-re-drive refusal classes are untouched: green-basis drift
  whose evidence postdates the reset, red-basis born-green placeholders
  (#1162), vacuous green (#1259), scaffolded (#912).

### 3. `services/step_runner.dart` + `commands/run_driver_core.dart` (accept `adopted` as terminal make success)

- `StepRunner`: the make success predicate
  (`green | skipped | green-with-failed-build`) gains `adopted`.
- Run driver: the terminal make-success arm keyed on
  `result.outcome == 'skipped'` (bug #986 — record green evidence when
  the child's write did not land, advance GREEN, continue) gains the
  same handling for `adopted`, printing
  `[run] <id> make -> green (adopted)` and emitting the `adopted` step
  outcome. The healthy exit-0 path needs no change (make writes its own
  green evidence; `_evidenceMisfire` finds it).

### 4. `commands/doctor_command.dart` (prescription matches reality)

- The `evidence-without-artifact` arm (2d) keeps the prescription
  `zfa tdd run <feature>` (it is the only recovery and now it actually
  completes) but the explanation line MUST describe the real
  mechanics: run reconciles the tombstoned behaviors to pending and
  re-enters at gen; make adopts each re-driven subject whose
  certification the reset invalidated (the `adopted` outcome) instead
  of dead-ending at `subject-drift`.

## Rationale for the adopted-outcome design

The #1036 refusal exists to prevent certifying green on a subject the
certified RED evidence never exercised (the born-green placeholder
class). A reset tombstone is the user's explicit "drop the
certification and start over": for the tombstoned class the certified
hash is stale by decree, and the re-drive's make sees exactly the state
the first drive saw (gen-fresh artifacts, no prior certification).
Adoption therefore reproduces first-drive semantics while staying
HONEST in accounting: the outcome is explicitly `adopted` (never
conflated with `skipped` or `green`), and the appended green evidence
binds the current subject hash, so any POST-adoption drift still
refuses.

## Verification strategy

- TDD behaviors B1–B10 (see tdd/test-list.md) as fixture-level tests in
  `test/plugins/tdd/`, mirroring `bug_1264_reset_done_state_phantom_test.dart`
  and `bug_840_recovery_commands_test.dart` conventions
  (`TddFixture`, `CliRunner(exitOnCompletion: false)`, the JSON verdict
  as the last stdout line).
- RED first (the new behaviors fail against the current code), then the
  implementation flips them green; refactor keeps the contracts.
- Only the touched contracts' test files are run (cloud-agent disk
  constraint): never the full suite.
