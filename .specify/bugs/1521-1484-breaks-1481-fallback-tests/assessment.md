# Bug Assessment: feature 1484 breaks the #1481 fatal unit-fallback tests (`plan_command_bug_1481_test.dart` red on `feat/1484-fr-manual-exemption`)

- **Slug**: 1521-1484-breaks-1481-fallback-tests
- **Created**: 2026-09-11
- **Source**: GitHub issue #1521 (regression on PR #1504 / branch `feat/1484-fr-manual-exemption`, HEAD `58ad4eed` — feature commits `ee9cc948` + follow-up `b34adae2`)
- **Verdict**: valid
- **Severity**: high

## Symptom

On the `feat/1484-fr-manual-exemption` branch, `dart test
test/plugins/tdd/commands/plan_command_bug_1481_test.dart` reports
`+5 -3: Some tests failed.` The three failures all sit in the group
`#1481: the two fallback classes are distinguishable`:

1. `a unit fallback renders the FATAL class (no declared trace, make
   will dead-end) while the scenario heals to declared` — expects the
   route line `route: U1 -> unit lane [fallback: no declared trace —
   make will dead-end`; actual output contains no unit route line at
   all, only the defaulted-FR warning `WARNING: FR-001 derives no unit
   behaviour — … recorded as a manual declaration in
   tdd/traceability.md.`
2. `a single summary line tallies the dead-end behaviors (no scanning
   42 route lines)` — expects `2 behaviors will dead-end at make — no
   declared contract trace (U1, U2)`; the tally line is never emitted.
3. `the tally counts PLURAL dead-ends correctly` — expects
   `3 behaviors will dead-end at make — no declared contract trace
   (U1, U2, U3)`; same missing tally.

## Root cause

Feature 1484 (`ee9cc948`) introduced default-to-manual routing for
unbound FRs in `lib/src/plugins/tdd/commands/plan_command.dart`: an FR
with no surviving `traces:` binding (and no explicit
`**Type**: manual` marker) is routed to a manual declaration in
`tdd/traceability.md` and announced with a per-FR warning plus remedy
line — it no longer produces a unit-lane fallback route row. The #1481
test fixture `_deadEndSpec` (two FRs, no `traces:`, no Layer Contracts
section) therefore yields **zero unit behaviors**: the pre-1484 fatal
class `[fallback: no declared trace — make will dead-end]` and the
dead-end tally (`N behaviors will dead-end at make — …`) are
structurally unreachable for unbound FRs. The #1481 tests (last
touched by `903240d5`) still assert that pre-1484 behavior. The
follow-up commit `b34adae2` re-bound five *other* fixtures stranded by
the same flip but missed this test file.

Verified in-source: the string `will dead-end at make` is no longer
reachable from unbound FRs — though it does still exist in
`plan_command.dart` (`_printDeadEndTally`, lines 2031–2035, built from
two concatenated literals, so a naive grep misses it; the
`no declared trace — make will dead-end` prefix at :2009 likewise),
while the manual-routing warning block (`WARNING: ${r.frId} derives no
unit behaviour — …` / `--> fix: add a `traces:` line naming a declared
contract row …`) lives at `plan_command.dart` lines 265–275.

## Remediation decision (issue options a vs b)

**Option (a) — update the #1481 dead-end-tally expectations to match
feature 1484's manual routing — is correct.** The tests assert
pre-1484 behavior that intentionally no longer exists: option (b)
would require resurrecting a fallback class that feature 1484
deliberately removed (the whole point of the flip is that a defaulted
FR must never reach `make` as an automated unit row that cannot
honestly pass). The manual-routing behavior is itself announced —
per-FR warning, both remedies, traceability recording — which is the
honest replacement for the retired fatal class.

## Hard constraints

- Fix ONLY the test expectations in
  `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`.
- Do NOT change `plan_command.dart` routing logic or feature 1484
  behavior.
- Must not break any other tests.
- `dart analyze` clean (no new warnings) on the changed file.

## Tests to add or update

All in `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
(group `#1481: the two fallback classes are distinguishable`):

- T-U1 (renamed from the FATAL-class test): an unbound FR routes to a
  manual declaration — warning rendered, both remedies named, no unit
  route line, no fatal fallback class — while the scenario in the same
  invocation heals to `[declared: type marker]` and the marker is
  written to spec.md.
- T-U2 (renamed from the dead-end-tally test): every unbound FR gets
  its own manual-declaration warning; no dead-end tally for
  manual-routed FRs.
- T-U3 (renamed from the plural-tally test): the per-FR warning scales
  to PLURAL unbound FRs (three FRs → three warnings), still no tally.
