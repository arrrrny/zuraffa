# Cycle Log: 1430-refactor-refresh-evidence

Deterministic fixtures: the CLI/driver rows drive the real make and refactor
command classes in-process over a hermetic temp feature (a subject file under
`lib/tdd/<feature>/`, a certified green cycle-log entry stamped with the
subject's sha256, injectable pass runner — mirroring the existing refactor
suites); no whole-suite runs.

## Baseline

- Behaviors derived: 3 acceptance (A-1430-1..3) + 6 unit (U-1430-1..6).
- Suite entry points: `test/plugins/tdd/commands/bug_1430_refresh_evidence_test.dart`
  (new) + the existing make/refactor/cycle-log suites for the regression pins.
- RED evidence lands here per cycle as behaviors are driven.
