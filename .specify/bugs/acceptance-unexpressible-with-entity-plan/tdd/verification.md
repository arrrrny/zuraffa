---
feature: .specify/bugs/acceptance-unexpressible-with-entity-plan (bug #923, pinned per bug extension TDD mode, branch audit)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: branch fix/923-acceptance-unexpressible-with-entity-plan (pre-PR HEAD)
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/3 killed, 1 equivalent # scope: the issue-#923 anchor contract in composition_targets.dart only, manual deliberate mutants
mutants_survived: 0
equivalent_mutants: 1
suite: "composition_targets_test +15 (9 issue-#923 group); composition_planner_test +7; compose_command_test +15 (A6b); make_command_test --preset=all +33 −4 (4 pre-existing, pristine-identical); tdd services chunk +476; chunked fast suite 70/70 chunks passed; dart analyze 47 infos = pristine baseline; dart format clean; real-CLI e2e: make A1 outcome=green on 0-green/2-entity-wired anchors"
---

# TDD Verification: bug #923 — acceptance composition against entity-wired unit subjects

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real (the make-level
core test A13b failed to compile against the pre-fix code —
`entityWired` did not exist — and the discovery contract it pins failed
with the exact #923 signature captured on the pre-fix tree:
`composition fallback disengaged: no green unit subjects to compose
against` → `outcome=unexpressible`; post-fix the same real-CLI fixture
reports `composition fallback: 0 green, 2 entity-wired unit subject(s)`
→ `outcome=green` exit 0), all three acceptance criteria from the issue
are covered, and two of three deliberate mutants were killed by the new
tests. The gaps: the entity-wiring probe reads the subject file with
`readAsStringSync` inside discovery (synchronous I/O in an async service —
bounded by the registry's existing sync existence checks, unmeasured),
one mutant is equivalent (documented below), and the workflow's
pre-committed `.specify/bugs/<slug>/{issue,assessment}.md` records exist
on no branch — reconstructed in this PR from GitHub issue #923 (the sole
triage input) and this session's root-cause work, as in the #737
precedent.

## Test-first evidence

| Behavior                                                                                     | Class  | Evidence                                                                                                                                                                                                                                                                                                  |
| -------------------------------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1 — an entity-wired unit subject (no green evidence) is a composable anchor; a plain non-wired stub is not; the wiring status rides the anchor | PROVEN | RED: the new `composition_targets_test.dart` group failed to compile pre-fix (`entityWired` undefined) — the contract did not exist. GREEN post-fix: U6 (wired anchor without green evidence, `entityWired` true), U7 (plain stub still `no-green-units`), U8 (green + wired anchors resolve together in test-list order), U9 (comment markers never anchor). |
| B2 — `zfa tdd compose` composes against an entity-wired anchor and names the wiring honestly | PROVEN | RED pre-fix: A6b's fixture state (green evidence stripped, subject wired) hit `outcome=no-green-units` exit 1. GREEN post-fix: `outcome=composed` exit 0, composed subject references `subject_u_001` with `composedUnitAnchors`, audit line carries `entity-wired`. |
| B3 — the acceptance make is never stuck at `unexpressible` when the units are entity-wired (THE issue's hard constraint) | PROVEN | RED captured verbatim on the pre-fix tree (real CLI, spec-004-shaped fixture): `composition fallback disengaged: no green unit subjects...` → `make: behavior=A1 outcome=unexpressible` exit 1. GREEN: A13b (fake pipeline) asserts `outcome=green` + compose/build both logged + green evidence appended + no `outcome=unexpressible`; real-CLI e2e (below) asserts the same through the REAL wire/compose/build pipeline. |
| B4 — the honest stops survive: zero composable anchors (neither green nor wired) still refuses, non-acceptance targets still fail closed, comment markers never anchor | PROVEN | Pre-existing U2/A6/A10/A11 pins pass unchanged post-fix (their fixtures carry no wired markers); new U7/U9 pin the refusal for plain stubs and comment-only markers; `no-green-units` machine code unchanged (compose's outcome mapping untouched). |
| B5 — the phase-1 deferral → phase-2 flip story is unchanged for green units (no regression on spec 052) | PROVEN | SC-021's composition contracts re-pinned by the still-green compose/make suites (A13/U19, A3-A8, U9-U16); SC-021 itself fails IDENTICALLY on pristine master (its fixture predates the #919 Template-Version gate — `plan` exits 3 on the missing marker before any composition code runs) and is documented as pre-existing, not fixed here (single-purpose PR). |

No assertion was weakened. The only amended existing output contract is
the anchor summary line (`N green unit subject(s)` → `N green, M
entity-wired unit subject(s)` when wired anchors exist); the zero-wired
form is byte-identical to the old text, so every pre-existing pin
(composition_planner_test U6/U6b anchor-count assertions, compose A4/A3,
make A13/U19) passes unmodified. No test was renamed out of a filter's
reach, skipped, or excluded; no coverage/mutation gate was touched.

## Real-CLI end-to-end evidence (this session)

Fixture mirroring spec 004 (`004-cloud-agent-task-dispatch`, Key Entity
Task, pure-prose acceptance scenarios), REAL `bin/zfa.dart`:

1. RED (pre-fix tree, units wired but not green):
   `zfa tdd make A1` → `composition fallback disengaged: no green unit
   subjects to compose against` → `make: behavior=A1 outcome=unexpressible`,
   exit 1.
2. Full-run transcript pre-fix (matches the issue verbatim):
   `[run] A1..A5 make -> unexpressible` / `-> deferred (phase 2)` while
   `U1..U4 make -> green`.
3. GREEN (post-fix tree): real `zfa tdd wire U1/U2 --entity Task`
   (`outcome=wired`, subjects carry `wiredEntityAnchor`), zero green
   entries in the cycle log, then `zfa tdd make A1` →
   `composition fallback: 0 green, 2 entity-wired unit subject(s) (U1, U2)`
   → `plan: composition fallback — 2 step(s)` (real `tdd compose A1` +
   real `build`) → `make: behavior=A1 outcome=green`, exit 0, and the
   composed subject imports both wired anchors
   (`package:tdd_fixture/tdd/004-cloud-agent-task-dispatch/u{1,2}_subject.dart`).

## Mutation results (manual deliberate mutants, composition_targets.dart only)

| Mutant | Change | Result |
| ------ | ------ | ------ |
| M1 | Disable the entity-wired probe (revert discovery to green-only) | KILLED — U6, U8, A6b fail (21 failing assertions across the three suites) |
| M2 | Remove the per-line comment strip (match the marker on the raw line) | EQUIVALENT — `_wiredEntityAnchor` is anchored (`^\s*final\s+Type\s+wiredEntityAnchor\s*=`), so a comment-prefixed line (`// final Type ...`) never matches with or without the strip; no reachable input distinguishes the mutant. The strip is defense-in-depth symmetric with wire's `_hasExecutableUnimplementedError`. U9 still pins both comment shapes against weaker (unanchored) regressions. |
| M3 | Mark wired anchors `entityWired: false` (lie in the audit trail) | KILLED — U6, U8, A6b fail (the honesty contract is load-bearing, not cosmetic) |

## Acceptance-criteria coverage (issue #923)

| Criterion | Status | Evidence |
| --------- | ------ | -------- |
| compose uses entity-wired subjects (U behaviors with `wiredEntityAnchor = Task`) as a basis for acceptance composition, even when the unit subjects are stubs | COVERED | U6/U8 (discovery), A6b (compose, real command), A13b (make, fake pipeline), real-CLI e2e step 3 (real wire → real compose → real build → green) |
| the acceptance path is expressible when the unit subjects are entity-wired, deferring the actual green transition to when the unit subjects are filled with real logic | COVERED | A13b: `outcome=green` with zero green units; composed-subject stamp names `[entity-wired]` anchors and defers the real green transition in writing; B4 keeps the honest stop when NOTHING is wired/green |
| a `zfa tdd run` with all U behaviors entity-wired completes the A behaviors to green (or honest red evidence for the parts that need real unit impl) | COVERED | Real-CLI e2e (make-level flip through the real pipeline); run-level phase deferral/flip mechanics unchanged (SC-021 mechanics re-pinned by A13/U19 + compose suites; SC-021's own pre-existing #919 breakage identical on pristine master) |

## Findings

| #   | Severity | Finding                                                                                                                                                                                                                       | Evidence                                                                             |
| --- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ |
| 1   | LOW      | The workflow stated `.specify/bugs/<slug>/{issue,assessment}.md` were already committed; they exist on no branch. Records were reconstructed in this PR from GitHub issue #923 (the sole triage input) and this session's root-cause work | `.specify/bugs/acceptance-unexpressible-with-entity-plan/assessment.md` header        |
| 2   | LOW      | Pre-existing failures pre-date this branch and are intentionally not remediated here (single-purpose PR): bug-657 verb-naming + spec-052 A11/U17 + bug-829 U-829g/U-829h in `make_command_test.dart --preset=all` (stash-verified pristine-identical); SC-021 e2e (pristine-identical #919 Template-Version gate) | Pristine-tree stash runs recorded this session; `make_command_test` fails the same 4 on master |
| 3   | LOW      | The wired-anchor probe uses `readAsStringSync` inside the async `discover` (the green path already used sync `existsSync`); I/O is bounded by registry-recorded artifact paths, but the mix of sync/async I/O is a smell the next touch should unify | `lib/src/plugins/tdd/services/composition_targets.dart` anchor loop                   |
| 4   | LOW      | `no-green-units` retains its historical machine code while its message now names both preconditions (green OR entity-wired) — kept for compose-outcome mapping stability; a future rename deserves a changelog note | `composition_targets.dart` / `compose_command.dart` (`ComposeOutcome.noGreenUnits`)   |
| 5   | INFO     | M2 is an equivalent mutant (anchored regex makes the comment strip unreachable on all line-comment shapes); block comments containing the exact marker shape are unhandled by BOTH the strip and the regex — accepted, the wire-emitted contract shape carries no such comments | Mutation section, M2 row                                                              |

## Discipline audit

- Red was real: the new contracts failed against pre-fix code (compile
  failure on the missing field; the #923 signature captured verbatim on
  the pristine tree before implementation began).
- No test was deleted, skipped, weakened, or moved out of reach; the only
  strengthened test (U9) grew strictly stronger (both comment shapes).
- `dart analyze` = 47 infos, byte-identical to the pristine baseline;
  `dart format .` clean; `git diff --stat` shows only the seven intended
  files.
- Chunked fast suite (the disk-safe runner cloud agents are directed to):
  70/70 chunks pass, including `test/plugins/tdd/commands` (+124) and
  `test/plugins/tdd/services` (+476).
