---
feature: tdd-make-never-wires-subject
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: db00ff5e
behaviors: 3
proven: 0
likely: 3
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool; deliberate mutant 1/1 caught (the gap itself, replayed)
mutants_survived: 0
suite: sc_017 real pipeline 1/1 (2:06); wire unit 6/6 + planner 6/6; tdd plugin --preset=all chunked ~402 passed / 0 failed; regression tier 279 passed / 1 pre-existing failure; test/cli 128/0, test/commands 49/0
---

# TDD Verification: `zfa tdd make` never wires the subject (#610)

**Verdict: PASS_WITH_GAPS.** The bug's acceptance — green is REACHABLE with
the real pipeline for an entity-bearing behavior — is proven end to end by
sc_017: a real fixture with real dependencies, real `gen` → `verify-red` →
`make` (real `entity create`, real `tdd wire`, real `build_runner` build),
certifying `outcome=green` in 2:06, with the subject wired by the pipeline
and the wiring step recorded in the green evidence. Gaps: test-first evidence
is `LIKELY` (red ran before the fix in-session; test + fix land in one commit
per repo convention), and mutation was sampled on the single highest-risk
behavior.

## Test-first evidence

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| B1 — real pipeline reaches green for an entity behavior | LIKELY | cycle-log Cycle 1 records the sc_017 red (1:47): real create + real build succeeded, `target test still fails after generation`, `outcome=generation-error` — the bug, reproduced as a test before the fix |
| B2 — the subject-implementation step exists as a generator surface and is recorded in green evidence | LIKELY | WireCommand implemented + registered; planner emits the step; sc_017 green run's cycle-log entry contains `tdd wire` between `zfa entity create` and `zfa build` |
| B3 — the wiring decision is folded into the epic 045 harness spec (precondition 5) | LIKELY | spec artifact updated in the same commit (specs/045 precondition 5: decision, rationale, plan shape, CRUD-branch scope note); never went red (documentation criterion), covered by the PR diff |

No pre-existing test was weakened. Two existing assertions were STRENGTHENED/
updated for the new plan shape (planner U6: 2 → 3 steps + wire argv pin;
sc_005 replay: 2 → 3 recorded invocations) — both are behavior changes this
fix introduces, not loosening.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | sc_017 drives a real `dart pub get` + real `build_runner` build (~2 min); it is the anchor test by the assessment's own request, but it couples the suite to pub.dev availability and adds minutes to the slow tier | `sc_017_real_pipeline_wires_subject_test.dart` |
| 2 | MED | WireCommand's wired body anchors the entity by TYPE reference (`final Type wiredEntityAnchor = <Entity>;`) rather than constructing it — minimal per 047 FR-005 and robust for field-bearing entities, but the pairing test only asserts non-`UnimplementedError`, so the anchor's presence (not deep semantics) is what green certifies | `wire_command.dart` `_renderWired` |
| 3 | LOW | The wire step's stub parser recognizes exactly the SubjectWriter stub signature; a hand-mutated stub shape is refused (U-W5) rather than rewritten — correct misfire-stop, but it means wire only owns files gen produced | `wire_command.dart` `_stubSignature` |

## Mutation results

No mutation tool in the profile; deliberate mutant on the highest-risk
behavior (B1 — the acceptance the whole fix exists for).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| remove the wire step from the entity plan (replay of the gap) | B1 (and B2) | No | sc_017 fails with the bug's exact signature (`target test still fails after generation`, `outcome=generation-error`); restoring the step returns green |

1 mutant sampled, 1 caught — it is the pre-fix red itself, so the mutant is
verified both ways. B3 (documentation) is not a mutation target.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| Issue #610 acceptance: green reachable with the REAL pipeline (no wrapper wiring) | B1 (sc_017) | Yes — real zfa end to end |
| Assessment remediation: subject-implementation step recorded as a normal GenerationStep in green evidence | B2 (sc_017 cycle-log assertion) | Yes |
| Task requirement: decision documented in PR body AND harness spec | B3 | PR diff + specs/045 |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Git history ordering: test + fix land in one commit (repo convention), so
  `PROVEN` is unreachable; evidence is `LIKELY` with the cycle log as
  corroboration.
- The CRUD/use-case plan branch (`zfa make <slug>` + `build`) still has no
  subject-implementation step; the assessment scopes this bug to the entity
  plan, and the 045 precondition-5 update explicitly records the CRUD branch
  as a remaining gap for the harness spec's own scope.
- Full-suite execution environment: suite runs are chunked per directory
  (the kernel compilation cache exceeds this sandbox's disk on a single
  `dart test` invocation). tdd plugin `--preset=all`: all files green
  (partial-run 322 + make 15 + runner-suite/verify-red 27 + sc001–008 26 +
  sc009–016 24 + sc017 1; one partial overlap in make_command_test between
  the timed-out full run and its complete re-run, ≈402 distinct passed /
  0 failed). Regression tier: 279 passed / 1 pre-existing failure
  (`cli_command_test.dart` CWD test — verified failing identically on the
  pristine base). `test/cli` 128/0, `test/commands` 49/0. Remaining
  fast-tier dirs: untouched by this diff (green at the #609 verification,
  same tree except tdd-plugin files), not re-run here.
- `dart analyze`: 0 errors; 10 warnings — byte-identical set to the pristine
  base; the touched files analyze clean (1 lint auto-fixed during the
  cycle). `dart format`: zero diffs on all touched files (2 pre-existing
  drift files elsewhere, untouched).
- Coverage tooling: not run; branch coverage of WireCommand not measured.
- Entity provisioning for bare projects (`zfa tdd init` provisions none of
  zorphy/build_runner — the assessment's related-gap note): sc_017
  provisions the fixture explicitly; the provisioning gap remains its own
  issue, out of scope here.
