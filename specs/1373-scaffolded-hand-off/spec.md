**Template Version**: `zuraffa-1.0`

# Spec: 1373-scaffolded-hand-off

GitHub issue: arrrrny/zuraffa#1373 (EPIC #1012 / #1008 two-cycle driver,
#912 defect 3 + #1258 author mode)

## Summary

When `zfa tdd run` reaches a SKIN/widget behavior whose generated test
carries the `zfa:tdd: scaffolded` marker, the run stops with the cryptic
`not-certified-red` resume hint: verify-red classifies the trivially-green
placeholder as unexpected-green (no red evidence), make refuses
not-certified-red, and nothing names the sanctioned
`zfa tdd make <id> --author --finders-file <path>` hand-off (#1258).

## Locked decisions

1. The run driver's make-failure handling gains an arm mirroring the
   #1308 vacuous-guard hand step: when the make outcome is
   `not-certified-red` AND the behavior's generated test carries
   `scaffoldedMarker`, the driver prints the author hand-off and stops at
   the named hand step `stopped_at=<id>:hand`.
2. Without the marker the generic make stop is byte-identical to today
   (`stopped_at=<id>:make` + the generic resume hint) — the arm is
   marker-gated, never a blanket pass.
3. The helper `_testCarriesScaffoldedMarker` mirrors the vacuous-guard
   probe: unreadable files fail open (marker absent).
4. State advance, save/clear, exit codes (`_exitStopped`), and the
   machine summary contract follow the #1308 hand-step pattern exactly.

## Functional requirements

- **FR-1**: marker present + not-certified-red → the hand step lines
  (`hand step: <id>:hand`, `--author --finders-file`) and
  `stopped_at=<id>:hand`.
- **FR-2**: marker absent → the generic make stop, unchanged.

## Acceptance scenarios

1. make refuses not-certified-red with the marker present → the hand
   step message + `stopped_at=<id>:hand` (B1).
2. make refuses not-certified-red without the marker → the generic stop
   + resume hint, no hand message (B2).

## Success criteria

- **SC-001**: The author hand-off names the sanctioned `--author
  --finders-file` path (issue #1258) instead of the cryptic resume hint.
- **SC-002**: The #1308 remedy suite and the stale-lane-plans suite stay
  green.

## Assumptions

- Messaging-only: the state advance and honest-stop semantics follow the
  #1308 hand-step pattern exactly.
