# Bug Assessment: read-cycle-evidence.sh python3 tier emits spaced JSON — jq-less E1/E2 grep fallbacks false-fail

- **Slug**: 1648-read-evidence-python3-spaced-json
- **Created**: 2026-09-16
- **Source**: https://github.com/arrrrny/zuraffa/issues/1648
- **Verdict**: valid (reproduced on this branch, see below)
- **Severity**: low (test-suite only; no production behavior bug)

## Report (verbatim or summarized)

`bash .specify/scripts/bash/tests/test_read_evidence.sh` run with a jq-less PATH (symlink farm of `/usr/bin`+`/bin`+`/sbin` minus `jq`, stock macOS bash 3.2) fails the E1 grep-fallback assertions: the haystack does not contain `"phase":"RED"` / `"behavior_id":"U9"`. Expected: all E-case grep-fallback assertions pass and E5 reports SKIP. See https://github.com/arrrrny/zuraffa/issues/1648.

## Symptom

In the **jq absent + python3 present** quadrant, the tier-2 (python3) parser of `read-cycle-evidence.sh` emits JSON with default (spaced) separators — `{"evidence": [{"phase": "RED", ...}]}` — while the E1/E2 grep fallbacks in `tests/test_read_evidence.sh` (before PR #1646) assert compact fixed strings (`"phase":"RED"`) that only the jq tier (`jq -cn`) and the tier-3 manual interpolation (`read-cycle-evidence.sh:295`) produce. The fallback assertions therefore false-fail even though the parsed data is correct.

## Reproduction

1. Build a jq-less PATH sandbox: symlink every `/usr/bin`, `/bin`, `/sbin` entry except `jq` into one directory (stock macOS equivalent: a machine without jq).
2. `PATH=<sandbox> bash .specify/scripts/bash/tests/test_read_evidence.sh`
3. Pre-#1646 tree → E1 "entries present (grep fallback)" and "behavior present (grep fallback)" FAIL with `haystack did not contain: ["phase":"RED"]`.
4. Post-#1646 tree (current master) → E1/E2 pass only because the test now whitespace-normalizes the haystack (`tr -d '[:space:]'`), a workaround that masks the tier-2/tier-3 output divergence instead of fixing it. The python3 tier still emits spaced JSON; run `bash .specify/scripts/bash/read-cycle-evidence.sh <log> --json` with python3 present and observe `{"evidence": [{"phase": "RED", ...}]}` (spaced), versus tier-3's `{"evidence":[{"phase":"RED",...}]}` (compact).

## Suspected Code Paths

- `.specify/scripts/bash/read-cycle-evidence.sh:185` — `print(json.dumps({"evidence": records}, ensure_ascii=False))` inside `parse_with_python()` (tier-2). Default `json.dumps` separators are `(', ', ': ')` → spaced JSON. **This is the defect.**
- `.specify/scripts/bash/read-cycle-evidence.sh:287-296` — tier-3 emits compact JSON both via `jq -cn '{phase:$phase,...}'` and via the manual interpolation `{"phase\":\"$(json_escape "$phase")\",...}` — the compact shape the fallbacks expect.
- `.specify/scripts/bash/tests/test_read_evidence.sh:71-78,118-121` — E1/E2 grep fallbacks; since PR #1646 they whitespace-normalize the haystack with a comment linking back to #1648 ("the production script stays untouched here").
- Contract: `specs/1444-spec-kit-boundary-scripts/contracts/read-cycle-evidence.md` — documents the JSON output (format illustrations are pretty-printed for readability; the three-tier cascade is contractually one parser cascade, so all tiers emitting one canonical shape is the intent; FR-005, SC-002).

## Root Cause Hypothesis

Confirmed (not merely a hypothesis): the tier-2 python3 parser calls `json.dumps` without `separators`, producing spaced JSON. Tiers 1/3 (jq and shell) emit compact JSON. The mismatch is invisible whenever jq or python-only-JSON-parsing consumers are used, and only surfaced as false-failing grep fallbacks in the jq-less test quadrant — which no prior "minimal env" run exercised because `/usr/bin/jq` was still on PATH.

## Proposed Remediation

**Fix the production side (one-sided, per the issue's hard constraint):** make the tier-2 parser emit compact JSON by passing `separators=(",", ":")` at `read-cycle-evidence.sh:185`:

```python
print(json.dumps({"evidence": records}, ensure_ascii=False, separators=(",", ":")))
```

Rationale for choosing the production side (not both sides):

- The test-side workaround already shipped in PR #1646 as an explicitly temporary measure ("the production script stays untouched here"); its comment becomes stale once the root cause is fixed.
- Compact output makes tier-2 byte-shape-consistent with tier-3 (`jq -c` / manual interpolation), restoring the "one parser cascade, one canonical output shape" intent (FR-005) and keeping the grep fallbacks meaningful for future regressions.
- JSON whitespace is insignificant to JSON consumers, so compacting cannot break downstream parsers; the contract's exit codes and field semantics are untouched.

**Tests (TDD red → green vehicle, not a second fix):** add one new E-case (E6) to `tests/test_read_evidence.sh` asserting the RAW tier-2 output (no whitespace normalization) contains the compact envelope `{"evidence":[{"phase":"RED"` and the compact field pairing `"behavior_id":"U9"`. E6 is RED on the pre-fix tree (spaced output) and GREEN post-fix. The existing E1–E5 assertions, including the #1646 fallback workarounds, stay byte-identical — the fallbacks are NOT touched by this fix.

**Files likely to change:**

- `.specify/scripts/bash/read-cycle-evidence.sh` (1 line)
- `.specify/scripts/bash/tests/test_read_evidence.sh` (one new E6 case appended before `t_report`)

**Tests to add or update:**

- E6 (new): tier-2 python3 emits compact JSON — no spaced separators (#1648). Runs in both jq-present and jq-less environments because tier-2 is selected by python3 presence, not jq presence.

## Risks & Considerations

- `read-cycle-evidence.sh` is one of the four boundary scripts (shellcheck gate in `run_tests.sh` Gate 1); the change is inside the embedded python3 heredoc, so shellcheck is unaffected, but the gate must be run to prove it.
- The #1646 test-side normalization becomes redundant after this fix. It is intentionally left in place (hard constraint: one-sided fix; removing it would be a second, test-side change). It is harmless: normalization of already-compact output is a no-op for the asserted field pairings, and it keeps the fallbacks robust to either emitter shape.
- Anything depending on the exact spaced formatting of tier-2 output would be affected; no such consumer exists (all documented consumers parse the JSON — the script's own contract), and tier-3's compact output already established the canonical shape.
- E5's `t_skip` path (jq absent) must keep reporting SKIP — unaffected by this change, but asserted in verification.

## Open Questions

- None. Root cause confirmed by direct inspection and reproduction; remediation follows the issue's suggested production-side option.
