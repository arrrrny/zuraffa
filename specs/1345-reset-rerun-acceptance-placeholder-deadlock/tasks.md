# Tasks — Spec 1345: reset→rerun acceptance placeholder deadlock (compose re-entry)

Dependency-ordered, MVP-first. T = test-first (TDD extension), I =
implementation.

- [ ] T1 (T) Red: `test/plugins/tdd/bug_1345_placeholder_re_drive_test.dart`
      B1 — a tombstoned acceptance-kind behavior whose on-disk subject is
      the born-green placeholder (the gen stub shape) and whose target
      test passes: `zfa tdd make` currently refuses
      `outcome=subject-drift` (the #1345 deadlock). Assert the POST-fix
      contract: exit 0, `outcome=adopted-placeholder`, green entry
      appended binding the CURRENT subject hash with the compose
      generation step recorded.
- [ ] T2 (I) `generation_plan.dart`: add `MakeOutcome.adoptedPlaceholder`
      (`adopted-placeholder`) documenting the #1345 re-entry class.
- [ ] T3 (I) `make_command.dart`: in the already-green re-drive block,
      add the #1345 branch — `reDrive && placeholderOnDisk && rowKind ==
      acceptance` falls through to generation planning (already-green
      becomes false; the composition fallback re-enters compose → build)
      and the final outcome reports `adopted-placeholder`; every other
      class keeps the existing adoption/refusal/skip behavior.
- [ ] T4 (T+I) B3 — run driver: the fake zfa make reports
      `outcome=adopted-placeholder` (exit 0); `zfa tdd run` grades it a
      terminal make success and completes (`result=complete`). Fix
      `step_runner.dart` (terminal-success list) and
      `run_driver_core.dart` (bug #986 fall-through covers the token).
- [ ] T5 (T+I) B4 — doctor: after a reset producing
      `evidence-without-artifact`, doctor's fix line names the
      placeholder re-entry (`adopted-placeholder`, issue #1345) and
      prescription stays `resume`. Fix `doctor_command.dart`.
- [ ] T6 (T) Refusal classes preserved (B5/B6): a tombstoned UNIT-kind
      placeholder re-drive still refuses `subject-drift`; a
      non-tombstoned born-green placeholder still refuses (the existing
      #1036 suite covers the no-tombstone class — kept green).
- [ ] T7 (I) `/speckit.analyze` cross-artifact drift fixes (spec ↔ plan ↔
      tasks ↔ test-list wording and class-predicate consistency).
- [ ] T8 (V) `tdd/verification.md`: red evidence (B1 pre-fix transcript),
      green evidence (post-fix), targeted-test results, `dart format .`
      clean, scope-fence checklist.
