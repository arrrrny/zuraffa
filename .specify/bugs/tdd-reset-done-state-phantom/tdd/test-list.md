# TDD Test List — tdd-reset-done-state-phantom (#1264)

Bug: https://github.com/arrrrny/zuraffa/issues/1264 — `zfa tdd reset <feature>`
leaves done-state for deleted artifacts: doctor says healthy, run skips the
behaviors, status reports engine green on nonexistent tests.

Target under test: the TDD plugin's reset/doctor/run-driver/status surfaces
(`lib/src/plugins/tdd/commands/reset_command.dart`,
`lib/src/plugins/tdd/commands/doctor_command.dart`,
`lib/src/plugins/tdd/commands/run_driver_core.dart`,
`lib/src/plugins/tdd/services/journal.dart`,
`lib/src/plugins/tdd/services/cycle_evidence.dart`), exercised end-to-end
through the real CLI (`CliRunner.runCapturing`) over the plugin's standard
temp fixture (`test/plugins/tdd/helpers/tdd_fixture.dart` — the same
conventions as the bug-840/682/1113 suites).

| ID | Behavior | Tier | Kind |
|----|----------|------|------|
| A1 | reset appends a journal tombstone (cycle `meta`, phase `reset`, `behaviors` = dropped ids) invalidating the dropped behaviors' green evidence | fast | unit (CLI surface) |
| A2 | doctor reports `evidence-without-artifact` as a drift (verdict `drift`, prescription `resume`, one fix: `zfa tdd run <feature>`) for green evidence whose backing test file reset dropped | fast | unit (CLI surface) |
| A3 | doctor stays healthy when the green evidence is backed by files on disk (no false drift on the healthy path) | fast | unit (CLI surface) |
| A4 | run does not skip the dropped behaviors — it re-drives them from gen (no `already done — skipping`, full gen→verify-red→make→refactor per behavior) | fast | integration (fake-zfa driver) |
| A5 | status does not report green without files — the stale green engine receipt demotes to `engine=red` with an `evidence-without-artifact` note; exit 1 | fast | unit (CLI surface) |

Acceptance criteria (from the issue's expected behavior): after reset, run
re-drives every behavior whose artifacts were dropped; doctor detects
orphaned evidence as a drift and prescribes exactly one recovery; status does
not report green for nonexistent tests. The brownfield bug-682 bootstrap
(evidence honored when its files exist) must not regress.
