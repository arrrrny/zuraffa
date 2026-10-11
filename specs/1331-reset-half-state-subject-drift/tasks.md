# Tasks — Spec 1331

Dependency-ordered, MVP-first. Behavioral tasks (B*) carry the TDD
red→green loop; the implementation tasks (T*) are the non-behavioral
scaffolding the behaviors drive out.

## Group 1 — Reset owns its deletion (SC-1, SC-2, SC-3)

- [x] T1. `reset_command.dart`: normalize recorded paths against the
  project root (`normalizeArtifactPath`) before the existence check;
  build the delete set from the normalized paths that exist.
- [x] T2. `reset_command.dart`: recursive generated-layout scan
  (`test/tdd`, `lib/tdd`) for generated-shape files whose provenance
  names a dropped behavior id; consult `foreignOwnerOf` so another
  feature's live registry ownership keeps the file (reported by name).
- [x] T3. `reset_command.dart`: pre-action output — path-drift warnings
  per dropped record whose normalized recorded paths do not exist,
  foreign-but-owned-looking files by name, the unified will-delete list;
  post-action validation — re-stat every planned deletion, prove the
  reported count matches the actual deletions, name any survivor;
  verdict details `path_drift` / `foreign_owned_looking` /
  `deleted_files`.
- [ ] B1. (behavior) reset deletes a drifted-path file whose provenance
  names a dropped behavior id (relative recorded path, reset run from a
  different CWD) — RED: the file survives today.
- [ ] B2. (behavior) reset deletes a generated-shape file at a drifted
  namespaced path (recorded path flat, file namespaced) — RED today.
- [ ] B3. (behavior) reset warns by name for each dropped record whose
  recorded paths did not exist and reports the deleted count matching
  actual deletions (verdict details present) — RED today.
- [ ] B4. (behavior) reset reports actual deletions equal to the printed
  "will delete N owned files" list (post-deletion validation, zero
  survivors) — RED today (no validation emitted).
- [ ] B5. (behavior) a generated-shape file another feature's live
  registry owns is NEVER deleted and IS reported by name; unmarked
  files stay foreign — proven by test (this already holds; guards the
  new scan).

## Group 2 — Make adopts the re-drive class (SC-4, SC-5)

- [ ] T4. `models/generation_plan.dart`: add `MakeOutcome.adopted`.
- [ ] T5. `services/journal.dart`: add `JournalReader.lastResetTombstone`
  returning the last tombstone's behavior ids + timestamp (parse-safe;
  absent/corrupt fails closed).
- [ ] T6. `commands/make_command.dart`: the alreadyGreen branch probes
  the tombstone; the re-drive class (tombstoned AND last green predates
  it) adopts — no `_subjectDriftRefusal` consult, adoption note printed,
  `outcome=adopted`, green evidence binding the current subject hash.
- [ ] B6. (behavior) make on a tombstoned behavior whose surviving green
  evidence predates the reset adopts the passing subject: exit 0,
  `outcome=adopted`, green evidence with the CURRENT subject hash — RED
  today (subject-drift refusal).
- [ ] B7. (behavior) `zfa tdd run` re-drive of the half-state reaches
  `result=complete` with the adopted make (no `subject-drift` stop) —
  RED today.
- [ ] B8. (behavior) refusals preserved: a green-basis drift whose last
  green postdates the last reset still refuses `subject-drift`; a
  feature with NO tombstone keeps refusing; born-green placeholder
  classes untouched — proven by test.

## Group 3 — The loop accepts adopted; doctor tells the truth (SC-6)

- [ ] T7. `services/step_runner.dart`: make success predicate gains
  `adopted`.
- [ ] T8. `commands/run_driver_core.dart`: the terminal make arm
  (`outcome == 'skipped'`) gains `adopted` — record green evidence when
  the child's write did not land, advance, print
  `make -> green (adopted)`, emit the adopted step outcome.
- [ ] T9. `commands/doctor_command.dart`: the evidence-without-artifact
  `--> fix:` explanation names the actual mechanics (reconcile to
  pending, re-enter at gen, make adopts — no subject-drift dead-end).
- [ ] B9. (behavior) doctor's `--> fix:` line for the
  evidence-without-artifact drift names the re-drive adoption the run
  performs (text matches reality) — RED today (text promises an
  executable path that dead-ends).
- [ ] B10. (behavior) end-to-end: reset a completed feature → doctor
  prescribes run → run completes (`result=complete`) → doctor healthy
  after the re-drive — RED today (run dead-ends at A2:make
  subject-drift).

## Group 4 — Verification and hygiene

- [ ] T10. `dart analyze` clean on every touched file; `dart format .`
  leaves zero diffs; targeted tests only (never the full suite — disk
  constraint); fixture/build-artifact cleanup after each phase.
- [ ] T11. tdd/verification.md: record red evidence (B1–B4, B6, B7,
  B9/B10 failed before the fix), green evidence (the same behaviors pass
  after), and the mutation check (a tampered assertion flips the
  behavior red) with the actual pass/fail counts and the PROVED vs
  NOT-PROVED success-criteria statement.
