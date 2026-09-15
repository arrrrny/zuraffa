# Bug Issue: read-cycle-evidence.sh python3 tier emits spaced JSON; test grep-fallbacks expect compact — jq-less suite run fails E1

- **Slug**: 1648-read-evidence-python3-spaced-json
- **Fetched**: 2026-09-16
- **Issue**: 1648
- **URL**: https://github.com/arrrrny/zuraffa/issues/1648
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

### Misfire report

**Command**: `bash .specify/scripts/bash/tests/test_read_evidence.sh` with a jq-less PATH (symlink farm of `/usr/bin`+`/bin`+`/sbin` minus `jq`, stock macOS bash 3.2)

**Expected**: all E-case grep-fallback assertions pass (they are the declared fallback for jq absence), E5 reports SKIP.

**Actual**:

```text
Testing E1: parses RED/GREEN/REFACTOR entries into JSON with fields
  ✓ PASS: E1 succeeds (exit code)
  ✗ FAIL: E1 entries present (grep fallback)
      haystack did not contain: ["phase":"RED"]
  ✗ FAIL: E1 behavior present (grep fallback)
      haystack did not contain: ["behavior_id":"U9"]
```

**Root cause**: `read-cycle-evidence.sh:185` — the tier-2 (python3) parser emits `json.dumps({"evidence": records})` with DEFAULT separators, i.e. spaced JSON:

```json
{"evidence": [{"phase": "RED", "behavior_id": "U9", ...}]}
```

while the test fallbacks in `tests/test_read_evidence.sh` assert compact fixed strings (`"phase":"RED"`) that only the jq tier (`jq -c`) and the tier-3 manual interpolation (line 295) produce. The quadrant **jq absent + python3 present** was never exercised (previous "minimal env" runs still had `/usr/bin/jq`), so the mismatch shipped unnoticed.

**Impact**: test-suite only — the E1/E2 grep fallbacks false-fail without jq. No production behavior bug (consumers parse via the same cascade the script itself documents).

**Suggested fix (either side)**:

- production: `json.dumps(..., separators=(",", ":"))` in the tier-2 parser, or
- tests: normalize whitespace out of the haystack before fixed-string matching (the pattern `tests/test_read_evidence.sh` E3 already uses).

PR #1646 respects the hard constraint of not touching the four boundary scripts, so it applies the test-side workaround with a comment linking back here.

**Acceptance criteria**:

1. E1/E2 grep fallbacks pass without jq on stock macOS bash
2. The python3 tier either emits compact JSON or tests normalize whitespace
3. No regression on jq-present path
4. E5 SKIP still reports correctly

**Hard constraints**: Fix the test fallbacks or the python3 tier's separator — not both sides simultaneously without cause. One PR per bug.

**Related**: #1646 (boundary scripts PR — hard constraint), #1466 (boundary scripts feature)

## Comments

None.
