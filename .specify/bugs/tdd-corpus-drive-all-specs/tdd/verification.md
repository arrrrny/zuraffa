---
feature: tdd-corpus-drive-all-specs
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 17a40434
behaviors: 18
proven: 0
likely: 15
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: n/a # no mutation tool in this environment; no deliberate mutants run
mutants_survived: 0
suite: fast tier 62 chunks passed / 5 slow-only skips / 2645 passed / 0 failed (chunked per directory, kernel caches cleared); slow corpus run-command suite 23 passed / 0 failed; pre-existing corpus suites (status/audit/manifest/progress/step-runner/import) 54 passed / 0 failed; dart analyze 47 issues = master baseline (all info, 0 on touched files); dart format clean on all touched files
---

# TDD Verification: `zfa tdd corpus run --plan` — dependency-ordered corpus driving with resume, spec-hash provenance, and the plan-gap ledger (#836)

**Verdict: PASS_WITH_GAPS.** The bug is fixed test-first: the RED suite
(`tdd/red-evidence.log`) ran 18 tests against unmodified master and 15 failed
for the right reasons — `Could not find an option named "--plan"`, manifest-order
driving with no dependency ordering, no `spec_hash` in progress, no drift exit,
no plan-gap ledger entries. After the fix all 18 pass and every pre-existing
corpus suite passes unchanged. Gaps: test + fix land in one commit (repo
convention), so git ordering alone proves only `LIKELY` for the 15 red-first
behaviors; mutation strength is unmeasured (no mutation tool in this
environment); and 3 behaviors are vacuous-pre-fix guards (they passed before the
fix because plan mode did not exist at all) — classified NOT_APPLICABLE rather
 than red-first.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B-001 — `--plan` orders dependent manifest features after their declared dependencies (markdown `→`/`->` edges) | LIKELY | red: `Could not find an option named "--plan"` + reverse-order fixture drove f3-dep before f1-base; green: exact 6-invocation order f1→f2→f3 with interleaved verify. Cycle: session transcript; test + fix in one commit → `LIKELY` not `PROVEN` |
| B-002 — independent features keep manifest order; a no-edge plan is a valid no-op | LIKELY | red: plan rejected outright ("declares nothing"); green: manifest order preserved, plan note printed. An implementation bug found mid-loop (empty plan wrongly rejected) failed this test and was fixed before green |
| B-003 — TUPEC inventory.json orders by dependencies (id→name mapping) | LIKELY | red: no `--plan`; first green attempt failed AGAIN (dep keyed by plan id unresolved against manifest name — implementation bug observed, fixed); green: f1-base driven before f2-mid |
| B-004 — unknown feature in a plan edge stops honestly (exit 2), nothing driven | LIKELY | red: usage error; green: exit 2, message names `f9-ghost`, fake-zfa call log empty |
| B-005 — dependency cycle stops honestly (exit 2), nothing driven | LIKELY | red: usage error; green: exit 2, cycle members named, nothing driven |
| B-006 — missing plan file stops honestly (exit 2), nothing driven | LIKELY | red: unknown-option error was NOT exit 2 (failed for a different reason than the assert); green: exit 2 with the plan path named |
| B-007 — machine summary carries `order=topological` in plan mode | LIKELY | red: no `--plan` option; green: summary line ends `order=topological`; U30 asserts the token is ABSENT without the flag |
| B-008 — resume with `--plan`: done features never re-driven, remaining order stays topological | LIKELY | red: no `--plan`; green across two drives: `tdd run f1-base` appears exactly once, f3-dep after f2-gap on the resume drive |
| B-009 — done feature records sha256 of its spec.md | LIKELY | red: no `spec_hash` key; green: 64-hex hash persisted in progress.json |
| B-010 — spec drift on a done feature stops the next run with exit 3 BEFORE driving anything | LIKELY | red: no drift detection (second drive happily re-drove); green: exit 3, "evidence drift" message names the feature, fake-zfa call log byte-identical across the stopped drive |
| B-011 — pre-#836 progress without a recorded hash never false-positives | NOT_APPLICABLE (guard) | passed pre-fix (the no-plan path was already correct) and stays green; pins backward compatibility |
| B-012 — declared criterion with no behavior lands in the ledger (step=plan, outcome=missing_behavior, expected_result=behavior) | LIKELY | red: no plan mode → no entries; green: exactly one entry with the three fields pinned |
| B-013 — a covered criterion is never ledgered | NOT_APPLICABLE (guard) | passed pre-fix vacuously (no plan mode); post-fix it asserts the real invariant against live plan mode |
| B-014 — plan gaps do not duplicate across resumes | LIKELY | red: no entries at all; green: two drives → still exactly one plan-gap entry |
| B-015 — a criterion becoming covered resolves the open gap as a NEW resolution entry | LIKELY | red: nothing; green: `kind=resolution` appended, original entry untouched (append-only) |
| B-016 — machine summary counts plan gaps in `gaps=` | LIKELY | red: no `--plan`; green: `gaps=1` in the summary line |
| B-017 — a composing feature never drives before its composed dependency (#827 namespacing makes the composition referenceable) | LIKELY | red: no `--plan`; green: unit-base's run precedes acc-composes' run despite the manifest listing the acceptance feature first |
| B-018 — without `--plan` the FR-001 manifest-order contract is unchanged (no `order=` token) | NOT_APPLICABLE (pre-existing guard) | passed pre-fix on master and stays green — the regression guard for the zero-risk requirement |

## Weakened-existing-test audit

No pre-existing test was weakened: no assertion removed, loosened, renamed out
of a filter's reach, skipped, or filtered; no threshold lowered. The only
touched test infrastructure is `helpers/corpus_fixture.dart` (additive helpers
`writePlan`/`writeSpec`/`writeTestList`; every pre-existing fixture consumer
passes unchanged). The ledger model's `expected_result` validation set was
extended (`complete|pass` → `complete|pass|behavior`), and the existing ledger
store tests pass unchanged — a widening, not a weakening. Two files the
formatter flagged (`gen_namespacing_827_test.dart`,
`migrate_paths_command.dart`) carry PRE-EXISTING formatting drift from master
and were deliberately left untouched to keep the diff minimal.

## Smell pass

No HIGH smells found. The suite asserts only observable effects (exit codes,
the fake-zfa argv log, ledger JSON, progress JSON, the machine summary line) —
the repo's canonical corpus-test style, shared with
`corpus_run_command_test.dart`. One LOW note: B-001 and B-017 both pin
dependency-first ordering on different fixtures (markdown edges vs the
composition framing); kept deliberately, since B-017 is the composition-order
guarantee the issue calls out by name.

## Criteria traceability

| Criterion | Behaviors | Covered |
| --------- | --------- | ------- |
| FR-836-1 (plan input + topological order + resume + honest plan errors) | B-001..B-008 | yes |
| FR-836-2 (provenance: spec-hash binding, drift = exit 3) | B-009..B-011 | yes |
| FR-836-3 (plan-gap ledger = the completeness proof) | B-012..B-016 | yes |
| FR-836-4 (cross-feature composition ordering) | B-017 | yes |
| FR-836-5 (scaled-down corpus smoke in the CI fast tier) | B-018 + the suite's tier placement | yes |

FR-836-5 note: the suite is deliberately NOT tagged `slow` (its only
subprocesses are the scripted fake zfa — no pub get, no build_runner), so it
runs in the default fast tier that CI executes on every push; it passed inside
the chunked fast-tier run (`test/plugins/tdd/commands` chunk, 58 tests).

## Remediation tasks

- [ ] Measure mutation strength for the plan driver (CorpusPlan.orderManifest,
      the drift gate, plan-gap reconciliation) when a mutation tool is
      available in the environment; triage any survivor against B-001..B-018.
- [ ] When the real 120-feature rewrite plan lands in the driving repo, run
      `zfa tdd corpus run --plan rewrite-plan.md` end-to-end and attach the
      summary line + gap ledger to the epic's proof artifact.
