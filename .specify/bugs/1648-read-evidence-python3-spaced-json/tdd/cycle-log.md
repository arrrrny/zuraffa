# TDD Cycle Log: Bug #1648 read-cycle-evidence tier-2 spaced JSON

**Feature**: 1648-read-evidence-python3-spaced-json
**Created**: 2026-09-15

This log is written in the format `.specify/scripts/bash/read-cycle-evidence.sh`
parses: every entry is an `## <timestamp> - <PHASE> - <behavior-id>` heading with a
`Behavior:` line and an `Evidence:` block, and entries are separated by `---`.
Phases are limited to RED, GREEN and REFACTOR. Narrative headings without a
timestamp (such as `## Baseline`) are not evidence entries.

## Baseline

One behavior (U-1648-b1) derived from `assessment.md` before any code change:
tier-2 (python3) `--json` output must be compact — byte-shape-consistent with
the jq and tier-3 emitters — so the E1/E2 grep fallbacks and any fixed-string
consumer see one canonical shape. Driven with the LLM-guided fallback workflow
(zfa unavailable for this project: no `zfa` binary, no `.zfa.json`).

Pre-fix tree state:

- `bash .specify/scripts/bash/read-cycle-evidence.sh <log> --json` (python3
  present) emitted `{"evidence": [{"phase": "RED", ...}]}` — spaced.
- The same command with python3 absent (tier-3) emitted
  `{"evidence":[{"phase":"RED",...}]}` — compact.
- Full boundary runner on the pre-fix tree: jq-present 25/25 GREEN; jq-less
  5/5 read-evidence cases green only via PR #1646's whitespace-normalization
  workaround (the defect was masked, not fixed).

Verbatim pre-fix suite output (both jq quadrants) is preserved in
`../red-evidence.md` (the bug directory one level up).

---

## 2026-09-15 17:35:00 - RED - U-1648-b1

Behavior: Tier-2 python3 emits compact JSON for --json (no spaced separators)

Evidence: New E6 case added to `.specify/scripts/bash/tests/test_read_evidence.sh`
asserting the RAW output (no whitespace normalization) contains the compact
envelope `{"evidence":[{"phase":"RED"` and the compact field pairing
`"behavior_id":"U9"`. Fails on the pre-fix tree in BOTH jq quadrants because
tier-2 is selected by python3 presence, not jq presence.

```text
===== jq-PRESENT (normal PATH) =====
Testing E6: tier-2 python3 emits compact JSON — no spaced separators (#1648)
  ✓ PASS: E6 succeeds (exit code)
  ✗ FAIL: E6 compact envelope (raw output)
      haystack did not contain: [{"evidence":[{"phase":"RED"]
  ✗ FAIL: E6 compact field pairing (raw output)
      haystack did not contain: ["behavior_id":"U9"]
SUITE cases_passed=5 cases_failed=1 cases_skipped=0

===== jq-LESS (sandbox PATH minus jq, python3 present) =====
  ✗ FAIL: E6 compact envelope (raw output)
      haystack did not contain: [{"evidence":[{"phase":"RED"]
  ✗ FAIL: E6 compact field pairing (raw output)
      haystack did not contain: ["behavior_id":"U9"]
SUITE cases_passed=5 cases_failed=1 cases_skipped=1
```

---

## 2026-09-15 17:38:00 - GREEN - U-1648-b1

Behavior: Tier-2 python3 emits compact JSON for --json (no spaced separators)

Evidence: Minimal production fix — `read-cycle-evidence.sh:189` now calls
`json.dumps({"evidence": records}, ensure_ascii=False, separators=(",", ":"))`.
E6 passes in both quadrants; E1–E5 unchanged (no regression); E5 JSON-parseability
still reports SKIP when jq is absent.

```text
===== jq-LESS =====
  File Summary: Passed: 6/6, Failed: 0/6, Skipped: 1
SUITE cases_passed=6 cases_failed=0 cases_skipped=1

===== jq-PRESENT =====
  File Summary: Passed: 6/6, Failed: 0/6, Skipped: 0
SUITE cases_passed=6 cases_failed=0 cases_skipped=0
```

Direct output check (same fixture as the red evidence):

```text
$ bash .specify/scripts/bash/read-cycle-evidence.sh defect-log.md --json
{"evidence":[{"phase":"RED","behavior_id":"U9","timestamp":"2026-09-15T10:00:00","evidence_text":"failing test output"}]}
$ ... | jq -e . >/dev/null && echo VALID
VALID
```

Tier-2 output is now byte-shape-identical to tier-3's for the same log and
still parses via `jq -e`.

---

## 2026-09-15 17:41:00 - REFACTOR - U-1648-b1

Behavior: Tier-2 python3 emits compact JSON for --json (no spaced separators)

Evidence: Refactor sweep while green — no changes needed or made. The fix is a
one-line separator change plus a rationale comment. Repo-wide check: the fixed
call is the ONLY `json.dumps` in `.specify/scripts/bash/*.sh`, so no other
spaced-JSON emitter remains. Full boundary runner re-run while green (with
shellcheck 0.10.0 gate): jq-present `Passed: 25/25 — VERDICT: ALL GREEN`;
jq-less `Passed: 25/25, Skipped: 1` (E5 JSON-parseability, jq absent, by
design; a transient T7 failure was a sandbox artifact — `stat` missing from
the jq-less PATH farm, not a code path — and cleared once `stat` was added).

```text
shellcheck OK: sync-behaviors-to-tasks.sh
shellcheck OK: read-tdd-profile.sh
shellcheck OK: read-cycle-evidence.sh
shellcheck OK: tick-behavior-task.sh
Passed: 25/25
Failed: 0/25
VERDICT: ALL GREEN
```
