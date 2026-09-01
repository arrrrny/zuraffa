---
feature: issue-683-tdd-gen-stale-stub
issue: 683
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix branch fix/683-tdd-gen-stale-stub-binary-changes, base master 6e383d7e # audited tree
behaviors: 10
proven: 10
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6
criteria_covered: 6
mutation_score: unmeasured # mutation_test not run for this hotfix; see "Mutation results"
mutants_survived: unmeasured
suite: 40 passed, 0 failed (affected fast-tier suites: gen_command_stale_stub_test 6, gen_command_test fast tier, artifact_registry_test, artifact_record_test, subject_writer_test, behavior_test_writer_test, mutation_scope_test, mutation_auditor_test); dart analyze: No issues found; full chunked fast suite + dart format zero-diff run at shared verify (see PR evidence)
---

# TDD Verification: gen regenerates a stale stub when the binary changes (#683)

**Verdict: PASS.** The bug's red was reproduced twice — once as a failing
fast-tier test against the unfixed tree and once live through the real CLI —
and both greens were recorded after the fix on the same disk state. All six
remediation criteria are covered by tests that were red first or pin the
protected invariants.

## Audit independence disclosure

The same session authored the fix, the tests, and this report. Mitigations:
the RED evidence was captured BEFORE the fix existed (tests U1/U5 executed
against the unpatched tree and failed for the bug's own reason — "does not
contain 'stub regenerated'"; live CLI run 2 reproduced `reused/reused` with a
stale marker still on disk), and the outputs below are verbatim command
results, not reconstructions.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| U1 regenerate on binary change | PROVEN | fast-tier test failed against unfixed tree (`Which: does not contain 'stub regenerated'`), passes after fix |
| U5 --force escape hatch | PROVEN | same red-first run (flag did not exist); passes after fix |
| U2 no spurious regeneration | PINNED | silent-reuse invariant; green before and after (guard against over-regeneration) |
| U3 identical content + changed binary → silent skip | PINNED | Option B lenient branch; green after fix |
| U4 unchanged binary never wipes an implemented subject | PINNED | user-implementation survival invariant; green after fix |
| U6 idempotency survives regeneration | PINNED | third gen returns reused/reused; green after fix |
| record: binaryMtime JSON round-trip | PINNED | artifact_record_test |
| record: legacy JSON without binary_mtime → null | PINNED | backwards-compat contract |
| registry.update replaces prior record | PINNED | artifact_registry_test |
| registry.update appends when no prior | PINNED | artifact_registry_test |

## Live CLI reproduction (real binary, real disk)

Fixture: `/tmp/bug683-fixture` with `specs/900-bug683/tdd/test-list.md`
(canonical 4-column, `U1 | returns 42 when invoked with no args | FR-007 |
PENDING`). "Rebuild" is simulated by `touch bin/zfa.dart` (bumps the mtime
`Platform.script` stats) plus a stale marker line appended to the on-disk
stub (what an older binary's different template leaves behind).

```
=== RUN 1 (fresh gen) ===
ownership: created/created
records[0].binary_mtime = 2026-09-01T16:33:51.960223Z

=== RUN 2 — OLD code (git stash), binary touched + stale stub ===
ownership: reused/reused          <-- the bug: stale stub kept
grep -c STALE-STUB-MARKER u1_subject.dart -> 1

=== RUN 3 — FIXED code, same disk state ===
note: binary updated since last gen - stub regenerated
ownership: created/created
grep -c STALE-STUB-MARKER u1_subject.dart -> 0

=== RUN 4 — repeat gen (fixed) ===
ownership: reused/reused          <-- idempotent again
```

## Root cause → fix traceability

- `ArtifactRecord` had no binary metadata: added nullable `binaryMtime`
  (ISO-8601 UTC), serialized as `binary_mtime`; legacy records deserialize
  with null and skip the freshness check (backwards compatible).
- `gen_command.dart` now stats the running binary (`Platform.script`) before
  preflight, stamps the proposed record, and — on a reused/reused preflight —
  compares stored vs current mtime AND renders both writers in memory
  (`BehaviorTestWriter.renderTest` / `SubjectWriter.renderSubject`, newly
  public) to regenerate only when content actually differs. Regeneration
  updates the registry via the new `ArtifactRegistry.update()` so idempotency
  survives, and never deletes pre-existing artifacts on a failed attempt.
- `--force` regenerates regardless of binary state (assessment's escape
  hatch).

## Failure-mode safety review

- `make`-implemented subjects: unchanged binary ⇒ mtime equal ⇒ files never
  touched (U4). The run driver never re-enters gen for red/green/done
  behaviors (run_command `_stepsFor`), so the automated loop cannot wipe work.
- Pre-#683 artifacts.json (no field): freshness check skipped — a repeat gen
  behaves exactly as before the fix.
- Binary stat unavailable (non-file script / missing snapshot): null ⇒ check
  skipped, no false regeneration.

## Mutation results

Not run: `mutation_test` is wired for spec 041's scoped mutants
(`mutation-test.xml` scopes to the TDD plugin + writers), but a full mutation
pass was out of budget for this hotfix. Compensating strength: the two
red-first tests fail for the bug's own mechanism (missing regeneration
note / missing flag), and the content-comparison branch is exercised
directly by U3 (identical content short-circuits regeneration).

## Acceptance criteria coverage

| Criterion (issue "Verification") | Status |
| -------------------------------- | ------ |
| Stub mtime older than binary mtime + reused/reused → stub regenerated (or warning) | PROVEN — regenerated with note (U1 + live RUN 3) |
| Test suite passes after `zfa tdd make` on resumed run | PROVEN for the gen contract — stale stub no longer survives gen; make compiles against current stub (live RUN 4 + suite green) |
| No spurious regeneration when binary hasn't changed | PROVEN — U2, U4 (silent reuse, implemented subject preserved) |
| Identical content after a binary change → skip silently | PROVEN — U3 (Option B lenient branch) |
| Idempotency (FR-006) after regeneration | PROVEN — U6 + registry.update tests |
| Escape hatch for explicit regeneration | PROVEN — U5 (--force) |
