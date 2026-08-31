---
feature: tdd-make-planner-omits-name-flag
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 00ed1451
behaviors: 2
proven: 0
likely: 2
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: n/a # no mutation tool; deliberate mutant 1/1 caught
mutants_survived: 0
suite: fast tier 2670 passed / 0 failed; tdd plugin --preset=all 345 passed / 0 failed; regression tier 279 passed / 1 pre-existing failure; integration+property tiers green
---

# TDD Verification: `zfa tdd make` planner omits required `-n` flag (#609)

**Verdict: PASS_WITH_GAPS.** The planner's emitted argv is now pinned to the
exact argv the real `EntityCommand` parses, by a fast-tier exact-argv unit pin
AND a slow-tier drift guard that executes the planner's emitted argv verbatim
against the real `bin/zfa.dart entity create` — the class of bug (fake-zfa
drift) can no longer pass CI silently. Gaps: test-first evidence is `LIKELY`
(red ran before the fix in-session, but test + fix land in one commit so git
ordering cannot independently prove it), and mutation was sampled on 1 of 2
behaviors.

## Test-first evidence

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| B1 — entity plan step carries `-n` (exact argv) | LIKELY | cycle-log Cycle 1 records the U3 pin red (`at location [2] is 'User' instead of '-n'`) before the fix; test + fix land in one commit, so history ordering is `LIKELY`, corroborated by the log |
| B2 — planner argv is accepted by the REAL zfa CLI | LIKELY | cycle-log Cycle 1 records the drift-guard red: real CLI exit 1, `Error: Entity name is required. Use -n or --name to specify.` on `[entity, create, User]`; green after fix (exit 0). Same-commit caveat as B1 |

No pre-existing test was weakened: the only touched existing test (U3) had its
assertion STRENGTHENED (from two token checks to an exact-argv pin). The suite
was green at baseline (`00ed1451`: tdd plugin 345/0).

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The drift guard shells the full CLI (~14s JIT compile per run); acceptable for the slow+integration tier it is tagged to, but it couples the test to a full CLI compile | `generation_planner_real_cli_test.dart` |
| 2 | LOW | The temp fixture pubspec carries `any` version constraints (dependency names only feed `EntityCommand`'s text gate; no resolution happens) | `generation_planner_real_cli_test.dart` fixture |
| 3 | LOW | B1's exact-argv pin is refactoring-sensitive by design (argv is the contract under test); noted so a future argv format change intentionally breaks it | `generation_planner_test.dart` U3 |

## Mutation results

No mutation tool in the profile; deliberate mutant on the highest-risk
behavior (B2 — the guard the whole fix depends on).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| drop `-n` from the planner-emitted argv (the original bug, replayed) | B2 (and B1) | No | U3 pin failed on argv mismatch AND real CLI rejected the plan (exit 1, name-required error); restored, suite green |

1 mutant sampled, 1 caught. B1 shares the mutation surface with B2 (same
emission site), so a second mutant would be equivalent. Not exhaustive beyond
this site.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| Issue #609 acceptance: real pipeline step 0 executes (`entity create -n <Name>`) | B1 (U3 pin), B2 (drift guard) | Yes — B2 runs the real `bin/zfa.dart` |
| Assessment remediation: slow-tier planner-argv-vs-real-CLI test exists | B2 | Yes |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- Git history ordering: test + fix land in one commit (repo convention:
  "a red test is committed alongside the implementation that turns it
  green, in the same commit"), so `PROVEN` is unreachable; evidence is
  `LIKELY` with the cycle log as corroboration.
- Full-suite execution environment: the repo-wide suite was run chunked
  per directory (kernel compilation cache exceeds this sandbox's disk on
  a single `dart test` invocation). Fast tier: 2670 passed / 1 skipped /
  0 failed. Regression tier: 279 passed / 1 pre-existing failure
  (`cli_command_test.dart` "find handles deleted CWD gracefully" —
  verified failing identically on the pristine base `00ed1451`).
  tdd plugin --preset=all: 345 passed / 0 failed. Integration (dir) 40/0,
  property 1/0, tdd integration preset (drift guard) 1/0.
- `dart analyze`: 0 errors; 10 warnings / 160 infos — byte-identical set
  to the pristine base; none in the three touched files. `dart format`:
  zero diffs on the touched files (2 pre-existing drift files elsewhere
  in the repo, untouched, out of scope).
- Coverage tooling: not run; branch coverage of the planner not measured.
- The CRUD branch (`zfa make <slug>`) positional-name concern from the
  assessment's risk note was NOT re-verified here — `MakeCommand` accepts
  a positional slug; flagged in the assessment for separate follow-up.
- Bug #610 (subject wiring) is a separate fix on its own branch; the
  2-step entity plan shape it needs to change was deliberately left
  untouched here (U6 still pins exactly 2 steps).
