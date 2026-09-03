---
feature: tdd-verify-hang-on-preexisting-red (bug #924)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 31b3ad62 # HEAD audited; the fix lands as this PR's single commit on top
behaviors: 3 # the three remediation points of the bug
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 48.87 # scope: the one changed service file, mutation_test 1.8.0, fast-tier test command
mutants_survived: 68 # triaged below: 0 MED/HIGH (M-1 remediated in-cycle), all LOW/equivalent
suite: chunked fast-tier folders OK (831 tdd-tier tests green); bug suite 7 fast unit + 2 CLI integration green
---

# TDD Verification: verify preflight hang on pre-existing red (bug #924)

**Verdict: PASS_WITH_GAPS.** All three remediation behaviors are implemented,
carry recorded red evidence, and are pinned through both the unit and the
real-CLI surface; the mutation phase was actually run against the changed
service and its one MED survivor was remediated in-cycle and re-measured.
The verdict is not `PASS` because the audit was not independent (the same
session wrote the fix and the tests), the mutation measurement is scoped to
`mutation_auditor.dart` alone with `verify_command.dart` unmeasured, and the
mutant test command necessarily excludes the integration tier where the real
spawn path is driven (mitigated by the M-1 refactor that moved the spawn
verdict classification into a fast-tier-pinned function).

## Test-first evidence

The tests and the fix land in one commit (this PR). Per the rubric, a test +
source change in one commit is `PROVEN` only when the cycle log holds the
red; the red evidence for every behavior is recorded in `tdd/cycle-log.md`
(R-1 product reproduction, R-2 contract-test red) and was captured in the
same session against pre-fix master @ 31b3ad62 before the fix was written.

| Behavior (remediation point) | Class | Evidence |
| --- | --- | --- |
| 1. `--timeout` respected; preflight phase bounded; timeout → NOT_ASSESSED + non-zero (64 usage class) exit | PROVEN | R-1 (master pays the baseline before the verdict); unit `the whole preflight phase stays bounded by the --timeout budget` (per-behavior budget exhaustion → `preflight timed out` → NOT_ASSESSED); V1 asserts the config verdict with a hanging feature test under `--timeout 0.2`; the 64-class exit is pinned by output (`❌ mutation audit gate: …`) per the bug_837 C3 in-process convention — the real process exits 64 via `exit()` (cli_runner.dart maps UsageException → 64) |
| 2. Per-behavior preflight (the profile's single/file template shape) with fail-fast + `preflight_scope_ran` diagnostics; no full-suite fallback | PROVEN | R-2 compile red (`runPreflightBehavior` / `preflightScopeRan` absent); unit fail-fast (red B-002 stops before B-003) + no-own-tests no-op + `preflight_scope_ran` equals the executed set; V2 end-to-end (red B-001 stops the run, B-002 never executed); M-1 mutant killed after refactor |
| 3. `gate: not_assessed` (missing mutation config) returned immediately, before any test process | PROVEN | R-1 behavioral red (master ran the preflight first, then generic `mutation audit failed`); unit config-first (preflight override never invoked, reason names the config); V1 end-to-end with a hanging feature test — the verdict arrives without any suite run |

No existing test was weakened, skipped, renamed out of a filter, or had an
assertion loosened: the only pre-existing suite edits are the additive
constructor/`PreflightResult`/report fields, and the full chunked fast-tier
suite passes with zero new failures (831 tests in the tdd tier alone).

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| F1 | LOW | 68 mutation survivors remain, all presentation/self-consistent: ~35 markdown literals and `!= null` render guards in `toMarkdown()` (the decisive gate strings are pinned by V1/V2 exact asserts), `<=`→`<` budget boundary (equivalent verdict — a zero-remaining child is killed by runTimed's zero timeout → same timed-out phase), cosmetic separators/diagnostic strings, self-consistent output-dir/config-path literals, XML whitespace in `buildScopedMutationConfig` | mutation report post-remediation: 65/133 killed (48.87%), 0 timeouts; per-line triage in `tdd/cycle-log.md` M-1 |
| F2 | LOW | The mutation measurement excludes `verify_command.dart` (untouched by this fix — the `--timeout` flag and the 64-class mapping already existed per #742) and cannot include the integration tier in the mutant command | `dart_test.yaml` excludes `slow` globally; mitigated by M-1 refactor + V1/V2 real-CLI coverage |
| F3 | LOW | The audit is same-session (not independent) and the per-behavior preflight adds N × `dart test` startup cost in the all-green case (bounded by the same phase budget; the red case — the bug's scenario — is strictly faster) | rubric independence criterion; design note in assessment.md Risks |

## Acceptance-criteria coverage (issue "Expected" → evidence)

| Issue Expected | Where proven |
| --- | --- |
| verify respects `--timeout <minutes>` (same as `zfa tdd make`) and exits non-zero on timeout | flag wired since #742 (verify_command.dart); phase-budget unit test pins the whole preflight under one wall clock; timeout → NOT_ASSESSED (never preflight_red) → UsageException → 64 usage class |
| full-suite preflight uses the per-behavior test when the feature has its own test files | `_defaultPreflight` runs each registered test file individually, fail-fast; `preflight_scope_ran` diagnostics; no full-suite fallback (no-own-tests no-op pinned) |
| `gate: not_assessed` (missing mutation config) returned immediately without running the full suite | config-first ordering in `MutationAuditor.run()`; V1 (hanging fixture) proves no suite run precedes the verdict |
| verify with many pre-existing failures returns in minutes with the appropriate non-blocking gate | V1/V2: gate arrives in seconds; fail-fast stops at the first red file |
