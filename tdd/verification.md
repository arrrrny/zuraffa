# tdd.verify — Bug #1648 the tier-2 python3 emitter must be compact like the rest of the cascade

- **Verified**: 2026-09-15, this session, on
  `fix/1648-read-evidence-python3-spaced-json` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`); bash bash-5.2 (linux) with a jq-less
  symlink-farm PATH simulating the stock-macOS-bash-3.2 quadrant; python3
  3.13.5; shellcheck 0.10.0; jq 1.7
- **Scope**: `.specify/scripts/bash/read-cycle-evidence.sh` (tier-2 separators
  + rationale comment), the new E6 case in
  `.specify/scripts/bash/tests/test_read_evidence.sh` (E1–E5 byte-identical),
  bug artifacts under `.specify/bugs/1648-read-evidence-python3-spaced-json/`
- **Mode**: LLM-guided fallback (`zfa` binary absent, no `.zfa.json` — same
  as the #1636/#1626 verifications)

## Verdict: PASS

## 1. Static analysis

```
shellcheck -x -S warning on the four boundary scripts (run_tests.sh Gate 1)
→ shellcheck OK: sync-behaviors-to-tasks.sh
→ shellcheck OK: read-tdd-profile.sh
→ shellcheck OK: read-cycle-evidence.sh      ← the modified script
→ shellcheck OK: tick-behavior-task.sh
```

```
dart format --output=none --set-exit-if-changed .
→ Formatted 2869 files (0 changed) in 7.60 seconds.   exit 0
```

```
dart analyze            (whole repo)
→ 106 issues found      (matches the pre-existing info-level baseline
recorded by the #1636 verification: 106, 0 errors, 0 warnings)
```

Zero `.dart` files changed on this branch (`git diff --name-only … -- '*.dart'`
is empty), so the scoped `dart analyze $(git diff --name-only HEAD -- '*.dart')`
gate has an empty file set by construction; the whole-repo run above proves no
baseline drift.

## 2. TDD discipline (REAL runs in this session)

- RED, pre-fix (verbatim in
  `.specify/bugs/1648-read-evidence-python3-spaced-json/red-evidence.md`):

```
Testing E6: tier-2 python3 emits compact JSON — no spaced separators (#1648)
  ✓ PASS: E6 succeeds (exit code)
  ✗ FAIL: E6 compact envelope (raw output)
      haystack did not contain: [{"evidence":[{"phase":"RED"]
  ✗ FAIL: E6 compact field pairing (raw output)
      haystack did not contain: ["behavior_id":"U9"]
jq-present: SUITE cases_passed=5 cases_failed=1 cases_skipped=0
jq-less:    SUITE cases_passed=5 cases_failed=1 cases_skipped=1
```

The red was proven in BOTH jq quadrants (tier-2 is selected by python3
presence, not jq presence), and the direct emitter diff on one fixture showed
the exact divergence: tier-2 `{"evidence": [{"phase": "RED", ...}]}` (spaced)
vs tier-3 `{"evidence":[{"phase":"RED",...}]}` (compact).

- GREEN, post-fix:

```
jq-present: SUITE cases_passed=6 cases_failed=0 cases_skipped=0
jq-less:    SUITE cases_passed=6 cases_failed=0 cases_skipped=1
            (the 1 skip is E5 JSON-parseability — jq absent, t_skip by design)
```

The fix was applied only after E6 was proven red; no assertion was edited to
make it pass retroactively (E1–E5 are byte-identical to the pre-fix tree —
`git diff` between the red and green commits touches only
`read-cycle-evidence.sh`).

## 3. Regression suites (REAL runs in this session)

```
bash .specify/scripts/bash/tests/run_tests.sh          (jq-present, shellcheck 0.10.0)
→ shellcheck OK on all four boundary scripts
→ Passed: 25/25   Failed: 0/25
→ VERDICT: ALL GREEN

PATH=<farm minus jq> bash .specify/scripts/bash/tests/run_tests.sh
                                                    (jq-less + shellcheck)
→ Passed: 25/25   Failed: 0/25   Skipped: 1 (E5 parseability, by design)
```

A transient T7 failure in the first jq-less runner pass was a **sandbox
artifact, not a code path**: the jq-less PATH farm lacked `stat`, which
`test_tick_behavior.sh` T7 uses to assert permission bits; adding `stat` to
the farm cleared it (7/7). No production file involved.

Dogfood check: the new `tdd/cycle-log.md` parses to the same three
RED/GREEN/REFACTOR entries through tier-2 and tier-3 of the FIXED script and
renders in text mode (`Found 3 evidence entries:`).

## 4. Mutation sampling (deliberate mutants, no mutation tool wired — per tdd-profile)

Mutants injected into `read-cycle-evidence.sh` tier-2, suite run after each,
script restored byte-identical after each (verified with
`git diff --quiet -- <script>`):

| Mutant | Change | jq-present result | jq-less result | Verdict |
|--------|--------|-------------------|----------------|---------|
| M1 | `separators=(", ", ": ")` (explicit spaced) | `Passed: 5/6, Failed: 1` — E6 envelope + pairing FAIL | `Passed: 5/6, Failed: 1, Skipped: 1` | KILLED |
| M2 | separators argument removed (exact pre-fix regression) | `Passed: 5/6, Failed: 1` — E6 kills | not re-run (same kill surface as M1) | KILLED |
| M3 | `indent=2` (pretty-print regression) | `Passed: 5/6, Failed: 1` — E6 kills | not re-run (same kill surface) | KILLED |

No surviving mutants in the sample; E6 kills the whole spacing-defect family
it was written for, in both quadrants. Restoration verified — the working
script's sha1 at audit close matches HEAD (`482852ab88c4…`), `git status` on
the script clean.

## 5. Acceptance criteria audit (issue #1648)

1. **E1/E2 grep fallbacks pass without jq on stock macOS bash** — PROVED:
   jq-less suite run `Passed: 6/6, Skipped: 1` post-fix (and they already
   passed pre-fix via the #1646 normalization; the fix removes the underlying
   divergence the normalization was masking, and E6 now guards the raw shape).
2. **The python3 tier either emits compact JSON or tests normalize
   whitespace** — PROVED (compact side): tier-2 emits
   `{"evidence":[{"phase":"RED",...}]}`, byte-shape-consistent with tier-3;
   `jq -e .` accepts it; dogfood cycle-log parses identically through both
   tiers.
3. **No regression on jq-present path** — PROVED: jq-present runner
   `Passed: 25/25 — VERDICT: ALL GREEN`; E1–E5 assertions untouched.
4. **E5 SKIP still reports correctly** — PROVED: jq-less runs show
   `⊘ SKIP: E5 JSON parseability (jq absent — nothing verified)` and the
   runner tallies `Skipped: 1` with the "a skip is NOT a pass" note.

Hard constraint honored — one-sided fix: the diff between the red and green
commits touches ONLY the production script (+1 line, +4 comment lines); the
test file changed only by ADDING E6 in the red commit; E1–E5 and the #1646
workaround are byte-identical throughout.

## 6. Residual notes

- The #1646 normalization in E1/E2 is now redundant but harmless (left
  untouched on purpose — removing it would be a second, test-side change).
- The contract's pretty-printed JSON example is illustrative; no doc drift
  introduced. Compact canonical shape could optionally be pinned in prose in
  a follow-up.
- Environment deltas vs the issue's repro (stock macOS bash 3.2): this
  audit used bash 5.2 on linux with a jq-less PATH farm; the suite targets
  bash 3.2+ constructs (harness design constraint) and the fallback path
  exercised is the same one the issue names.
