# Bug Fix: read-cycle-evidence.sh tier-2 emits compact JSON (#1648)

- **Slug**: 1648-read-evidence-python3-spaced-json
- **Fixed**: 2026-09-15
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/cycle-log.md, ../../tdd/test-list.md, ../../tdd/verification.md (fix ran in TDD mode — LLM-guided fallback, zfa unavailable), verbatim red runs in ./red-evidence.md

## Summary

The tier-2 (python3) parser of `read-cycle-evidence.sh` emitted `json.dumps(...)`
with DEFAULT separators (spaced JSON), diverging from the compact output of the
jq tier (`jq -cn`) and the tier-3 manual interpolation, which is what the E1/E2
grep fallbacks assert. Fixed one-sided per the issue's hard constraint: the
python3 tier now passes `separators=(",", ":")`, so every emitter of the
cascade produces one canonical compact shape and the jq-absent + python3-present
quadrant no longer false-fails.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `.specify/scripts/bash/read-cycle-evidence.sh` | modified | line 189: `json.dumps({"evidence": records}, ensure_ascii=False, separators=(",", ":"))` + 4-line rationale comment referencing #1648 |
| `.specify/scripts/bash/tests/test_read_evidence.sh` | added test case | new E6 (before `t_report`): pins the RAW compact shape (no normalization) in both jq quadrants; the existing E1–E5 assertions — including PR #1646's fallback workarounds — are byte-identical |
| `.specify/bugs/1648-read-evidence-python3-spaced-json/*` | added | bug artifacts: issue.md, assessment.md, red-evidence.md, fix.md (this file), test.md, tdd/cycle-log.md |
| `tdd/test-list.md`, `tdd/verification.md` | replaced | repo-convention TDD artifacts for this bug (per-bug replacement, same as #1544/#1589/#1626/#1636) |

## Diff Highlights

```diff
--- a/.specify/scripts/bash/read-cycle-evidence.sh
+++ b/.specify/scripts/bash/read-cycle-evidence.sh
-print(json.dumps({"evidence": records}, ensure_ascii=False))
+# Compact separators (",", ":") keep tier-2 byte-shape-consistent with the
+# other emitters of the cascade (jq -cn per entry and the tier-3 manual
+# interpolation both emit compact JSON), so the grep fallbacks and any
+# fixed-string consumers see one canonical shape. #1648.
+print(json.dumps({"evidence": records}, ensure_ascii=False, separators=(",", ":")))
```

## Tests Added or Updated

- `.specify/scripts/bash/tests/test_read_evidence.sh` E6 "tier-2 python3 emits
  compact JSON — no spaced separators (#1648)" — asserts the RAW `--json`
  output contains `{"evidence":[{"phase":"RED"` and `"behavior_id":"U9"`;
  runs whenever python3 is present (jq or not), skips honestly when python3 is
  absent (tier-2 never runs). Deliberately NO whitespace normalization: that
  is the #1646 workaround pattern that masked this bug.

## Local Verification

- Commands run:
  - `bash .specify/scripts/bash/tests/test_read_evidence.sh` (jq-present) →
    `SUITE cases_passed=6 cases_failed=0 cases_skipped=0` post-fix;
    `cases_passed=5 cases_failed=1` pre-fix (E6 red).
  - `PATH=<symlink farm minus jq, python3 present> bash .specify/scripts/bash/tests/test_read_evidence.sh`
    → `SUITE cases_passed=6 cases_failed=0 cases_skipped=1` post-fix (the 1
    skip is E5 JSON-parseability, by design); pre-fix `cases_passed=5
    cases_failed=1 cases_skipped=1` (E6 red).
  - `PATH=<shellcheck 0.10.0> bash .specify/scripts/bash/tests/run_tests.sh` →
    `shellcheck OK` on all four boundary scripts; `Passed: 25/25 — Failed:
    0/25 — VERDICT: ALL GREEN` (jq-present).
  - Same runner jq-less → `Passed: 25/25, Skipped: 1` (E5 skip only). A
    transient T7 failure was a sandbox artifact — `stat` missing from the
    jq-less PATH farm — not a code path; it cleared once `stat` was added.
  - Direct emitter check → tier-2 output now byte-shape-identical to tier-3
    for the same fixture and still parses via `jq -e .`.
  - Dogfood: the new `tdd/cycle-log.md` parses to the same 3 RED/GREEN/REFACTOR
    entries through tier-2 and tier-3, and renders in text mode.
- Manual checks: none beyond the above (the suite is the contract here).

## Deviations from Assessment

None. The assessment's preferred remediation (production-side separators) was
applied as proposed; E6 matches the "Tests to add or update" section. The
assessment's risk note held: shellcheck gate stays green (the change is inside
the embedded python3 heredoc).

## Follow-ups

- PR #1646's whitespace-normalization workaround in the E1/E2 fallbacks is now
  redundant (harmless; normalization of compact output is a no-op for the
  asserted pairings). Removing it would be a second, test-side change — left
  untouched on purpose per the one-sided-fix constraint. If a maintainer wants
  the stricter raw-shape fallbacks, do it in a follow-up PR referencing #1648.
- The contract `specs/1444-spec-kit-boundary-scripts/contracts/read-cycle-evidence.md`
  shows pretty-printed JSON examples for readability; no doc change needed —
  but if the maintainers want the compact canonical shape pinned in prose,
  one sentence could be added there (out of scope for this one-line fix).
