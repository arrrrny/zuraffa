# TDD test list — Bug #1648 read-cycle-evidence tier-2 spaced JSON

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1648-b1 | .specify/scripts/bash/tests/test_read_evidence.sh::E6 | unit | tier-2 (python3) `--json` output is compact — the RAW output (no whitespace normalization) contains the compact envelope `{"evidence":[{"phase":"RED"` and the compact field pairing `"behavior_id":"U9"`, byte-shape-consistent with the jq (`jq -cn`) and tier-3 manual-interpolation emitters; tier-2 is selected by python3 presence, so the assertion runs in both the jq-present and jq-less quadrants | issue #1648 criteria 1, 2 | GREEN |
| U-1648-p1 | .specify/scripts/bash/tests/test_read_evidence.sh::E1 | unit | pre-existing: RED/GREEN/REFACTOR entries parse into JSON with the right fields — jq tier asserts via jq queries, jq-less tier via grep fallbacks (PR #1646 normalization, untouched by this fix) | issue #1648 criterion 1 (no regression) | GREEN |
| U-1648-p2 | .specify/scripts/bash/tests/test_read_evidence.sh::E2 | unit | pre-existing: malformed entries skipped with a warning, valid entries kept — both tiers | issue #1648 criterion 3 (no regression) | GREEN |
| U-1648-p3 | .specify/scripts/bash/tests/test_read_evidence.sh::E3 | unit | pre-existing: zero-entry log yields `{"evidence":[]}` and exit 0 — both tiers | issue #1648 criterion 3 (no regression) | GREEN |
| U-1648-p4 | .specify/scripts/bash/tests/test_read_evidence.sh::E5 | unit | pre-existing: text mode summarizes entries; JSON parseability is asserted via `jq -e` when jq is present and reports SKIP (never a silent pass) when jq is absent | issue #1648 criterion 4 | GREEN (SKIP verified) |
| U-1648-p5 | .specify/scripts/bash/tests/run_tests.sh | unit | full boundary-suite runner: shellcheck gate on the four boundary scripts (incl. the modified read-cycle-evidence.sh) + all four test files aggregate green | issue #1648 criterion 3 (no regression) | GREEN |

## Red evidence (pre-fix, this session)

Verbatim runs preserved in
`.specify/bugs/1648-read-evidence-python3-spaced-json/red-evidence.md`:

- E6 (new, pre-fix): FAILED in both quadrants —
  `✗ FAIL: E6 compact envelope (raw output) — haystack did not contain:
  [{"evidence":[{"phase":"RED"]` and
  `✗ FAIL: E6 compact field pairing (raw output) — haystack did not contain:
  ["behavior_id":"U9"]`; `SUITE cases_passed=5 cases_failed=1` (jq-present)
  and `cases_passed=5 cases_failed=1 cases_skipped=1` (jq-less).
- Direct emitter diff pre-fix: tier-2 spaced `{"evidence": [{"phase": "RED",
  ...}]}` vs tier-3 compact `{"evidence":[{"phase":"RED",...}]}` on the same
  fixture.

## Green evidence (post-fix, this session)

- E6: PASSED in both quadrants — `Passed: 6/6, Failed: 0/6` jq-less
  (`cases_skipped=1` = E5 parseability, by design) and `Passed: 6/6,
  Failed: 0/6, Skipped: 0` jq-present.
- Full runner: `Passed: 25/25 — Failed: 0/25 — VERDICT: ALL GREEN`
  (jq-present) and `Passed: 25/25, Skipped: 1` (jq-less, E5 skip only).
- Cycle evidence: `.specify/bugs/1648-read-evidence-python3-spaced-json/tdd/cycle-log.md`
  (RED → GREEN → REFACTOR for U-1648-b1; parses through both tiers of the
  fixed script).
