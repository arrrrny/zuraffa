# Red evidence — Bug #1648 (pre-fix tree, this session)

Tree state: `fix/1648-read-evidence-python3-spaced-json` @ pre-fix working tree
(parent of the fix commit; E6 added, production script untouched).

New case E6 (`tier-2 python3 emits compact JSON — no spaced separators`)
asserts the RAW `--json` output of `read-cycle-evidence.sh` with **no
whitespace normalization** — the same normalization PR #1646 added to the
E1/E2 fallbacks, which is exactly what would mask the defect here.

## Defect demonstrated directly (same fixture, both emitters)

```text
$ bash .specify/scripts/bash/read-cycle-evidence.sh defect-log.md --json
{"evidence": [{"phase": "RED", "behavior_id": "U9", "timestamp": "2026-09-15T10:00:00", "evidence_text": "failing test output"}]}

$ env -i PATH=<sandbox-without-python3> bash .specify/scripts/bash/read-cycle-evidence.sh defect-log.md --json
{"evidence":[{"phase":"RED","behavior_id":"U9","timestamp":"2026-09-15T10:00:00","evidence_text":"failing test output"}]}
```

Tier-2 (python3, `json.dumps` default separators) emits spaced JSON; tier-3
(manual interpolation / `jq -cn`) emits compact JSON. The E1/E2 grep fallbacks
assert the compact shape — the issue's exact root cause.

## Suite run — jq-PRESENT (normal PATH), E6 red

```text
Testing E6: tier-2 python3 emits compact JSON — no spaced separators (#1648)
  ✓ PASS: E6 succeeds (exit code)
  ✗ FAIL: E6 compact envelope (raw output)
      haystack did not contain: [{"evidence":[{"phase":"RED"]
  ✗ FAIL: E6 compact field pairing (raw output)
      haystack did not contain: ["behavior_id":"U9"]

----------------------------------------
  File Summary: Passed: 5/6, Failed: 1/6, Skipped: 0
  Failed cases: E6: tier-2 python3 emits compact JSON — no spaced separators (#1648)
SUITE cases_passed=5 cases_failed=1 cases_skipped=0
```

## Suite run — jq-LESS (symlink-farm PATH minus jq, python3 present), E6 red

```text
Testing E6: tier-2 python3 emits compact JSON — no spaced separators (#1648)
  ✓ PASS: E6 succeeds (exit code)
  ✗ FAIL: E6 compact envelope (raw output)
      haystack did not contain: [{"evidence":[{"phase":"RED"]
  ✗ FAIL: E6 compact field pairing (raw output)
      haystack did not contain: ["behavior_id":"U9"]

----------------------------------------
  File Summary: Passed: 5/6, Failed: 1/6, Skipped: 1
  Failed cases: E6: tier-2 python3 emits compact JSON — no spaced separators (#1648)
  NOTE: 1 assertion(s) skipped — the environment lacked a verification tier; a skip is NOT a pass
SUITE cases_passed=5 cases_failed=1 cases_skipped=1
```

The jq-less skip is E5 JSON-parseability (`t_skip`, by design when jq is
absent) — matching the issue's "E5 reports SKIP" expectation.

## Baseline (pre-fix, E6 not yet present) — for the record

With only E1–E5, the jq-less run is green because PR #1646's
whitespace-normalization workaround absorbs the spaced tier-2 output:

```text
  File Summary: Passed: 5/5, Failed: 0/5, Skipped: 1
SUITE cases_passed=5 cases_failed=0 cases_skipped=1
```

This is why the bug survived: the workaround hides the tier-2/tier-3 output
divergence; E6 asserts the raw shape so the defect is visible again and the
production fix can be driven red → green.
