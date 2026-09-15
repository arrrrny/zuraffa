# Bug Verification: read-cycle-evidence.sh tier-2 compact JSON (#1648)

- **Slug**: 1648-read-evidence-python3-spaced-json
- **Tested**: 2026-09-15
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ../../tdd/verification.md (verdict: **PASS**; LLM-guided fallback — zfa unavailable) with red runs in ./red-evidence.md and the cycle log in ./tdd/cycle-log.md

## Summary

The bug no longer reproduces: in the jq-absent + python3-present quadrant the
suite is green (6/6 read-evidence cases, E5 parseability SKIPs by design), and
the tier-2 python3 emitter now produces compact JSON byte-shape-consistent
with the jq and tier-3 emitters. No regressions on the jq-present path (full
boundary runner 25/25, shellcheck gate green). Three deliberate spacing
mutants were all killed by the new E6 guard.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `PATH=<farm minus jq, python3 present> bash .specify/scripts/bash/tests/test_read_evidence.sh` | pass | `SUITE cases_passed=6 cases_failed=0 cases_skipped=1`; the issue's exact failure (`E1 entries present (grep fallback)`) cannot recur — E1/E2/E6 all green |
| Reproduction (pre-fix, for the record) | same command on the pre-fix tree, plus the raw emitter diff | fail (expected) | E6 red in both quadrants pre-fix; verbatim in ./red-evidence.md |
| New / updated tests | `bash .specify/scripts/bash/tests/test_read_evidence.sh` (jq-present) | pass | `SUITE cases_passed=6 cases_failed=0 cases_skipped=0` |
| Regression suite (jq-present) | `bash .specify/scripts/bash/tests/run_tests.sh` with shellcheck 0.10.0 | pass | `shellcheck OK` ×4; `Passed: 25/25 — VERDICT: ALL GREEN` |
| Regression suite (jq-less) | `PATH=<farm minus jq + shellcheck> bash .specify/scripts/bash/tests/run_tests.sh` | pass | `Passed: 25/25, Skipped: 1` (E5 by design); first-pass T7 failure was a sandbox artifact (missing `stat` in the farm), cleared, no code involved |
| JSON validity | `…read-cycle-evidence.sh <log> --json \| jq -e .` | pass | compact output still valid JSON |
| Tier consistency | same fixture through tier-2 and tier-3; dogfood parse of ./tdd/cycle-log.md | pass | identical 3-entry RED/GREEN/REFACTOR output from both tiers; text mode renders |
| Mutation sampling | M1 `(", ", ": ")`, M2 separators dropped, M3 `indent=2` | pass | all KILLED by E6; script restored byte-identical after each (sha1 `482852ab…` matches HEAD) |
| Static analysis | `shellcheck -x -S warning` (4 scripts); `dart format --output=none .`; `dart analyze` | pass | shellcheck green incl. modified script; format `0 changed`; analyze 106 info-level = pre-existing baseline, zero `.dart` files changed |
| Lint/type (scoped) | `git diff --name-only HEAD -- '*.dart'` | not-run (empty set) | shell-only change; scoped analyze has no files by construction, whole-repo run recorded instead |

## Output Excerpts

```text
===== post-fix, jq-less =====
  ⊘ SKIP: E5 JSON parseability (jq absent — nothing verified)
  File Summary: Passed: 6/6, Failed: 0/6, Skipped: 1
SUITE cases_passed=6 cases_failed=0 cases_skipped=1

===== post-fix, jq-present =====
  File Summary: Passed: 6/6, Failed: 0/6, Skipped: 0
SUITE cases_passed=6 cases_failed=0 cases_skipped=0

===== full runner (jq-present) =====
Passed: 25/25
Failed: 0/25
VERDICT: ALL GREEN

===== direct emitter output (post-fix) =====
{"evidence":[{"phase":"RED","behavior_id":"U9","timestamp":"2026-09-15T10:00:00","evidence_text":"failing test output"}]}
```

## Residual Risks

- The stock-macOS-bash-3.2 environment itself was simulated (jq-less PATH
  farm of `/usr/bin`+`/bin`+`/sbin` minus `jq`, per the issue's method) on
  linux/bash-5.2; the suite's bash-3.2 compatibility is unchanged by this fix
  (harness design constraint, unchanged code paths).
- PR #1646's whitespace normalization in E1/E2 remains in place (redundant,
  harmless); removal is deliberately deferred to a maintainer follow-up.

## Recommendation

Close the bug — verified end-to-end: acceptance criteria 1–4 are PROVED (see
../../tdd/verification.md §5), the fix is one-sided per the issue's hard
constraint, and the mutation sample shows the new guard actually bites.
