# Analysis: 1412-refactor-console-excerpt-tail

Cross-artifact consistency check (spec ↔ plan ↔ tasks ↔ code) before the
TDD loop. Verdict: CONSISTENT after two coverage fixes applied during the
pass (both folded back into the artifacts, nothing left drifted).

## Checks

| # | Check | Verdict |
|---|-------|---------|
| A1 | Every SC in spec.md has a test placement in tasks.md (SC-1..SC-3 → U-1412-1/2/3 driver tier; SC-4 → U-1412-4 driver tier; SC-5 → T003 unit groups; SC-6 → T004 verify) | OK |
| A2 | FR-4 (journal/cycle-log byte-identical) has BOTH a regression pin (U-1412-4: `200 of 251`) and a code-level constraint (plan.md: no `_outputTail` modification, no call-site changes) | OK |
| A3 | The `_analyzeGateRefusalPattern` read contract (#1407 make, #1472 registry) is pinned: spec US-3 scenario 3 + plan.md verdict-line rule + existing bug_1472 suite still green after T003 | OK |
| A4 | Hard constraint "console excerpt path only" vs T003 touching build_command.dart: the issue's acceptance criterion 4 explicitly sanctions the secondary nit "if scope permits"; T003 is marked scope-permitting and does not touch the driver's recorded-evidence paths | OK (sanctioned) |
| A5 | Fixture change (refactor `flood`) cannot regress existing suites: it is an ADDITIVE case branch keyed on a new outcome token; every existing refactor outcome (`ok`, `exit0:*`, default) is byte-identical | OK |
| A6 | Excerpt depth 10 vs marker wording: `_outputTail(compact, maxLines: 10)` produces `last 10 of M` — SC-2's asserted wording matches the helper's real output (no fabricated expectation) | OK |

## Coverage gaps found and fixed during analysis

1. **Short-transcript contract was implicit** — the spec's US-1 scenario 3
   existed but no FR carried it. Folded into FR-3 (compactness) with its own
   success criterion (SC-3) and test (U-1412-3).
2. **Green-run excerpt suppression** (US-2 scenario 2) had no task. It is
   guaranteed structurally (the excerpt only prints on failure paths) and is
   covered by the existing #1329 green-run pin (U-1329-7: a fully green run
   records no error evidence) — no new task needed; documented here instead
   of adding a redundant test.

## Drift risks monitored during implementation

- The marker's `of M` count reflects the COMPACTED (non-empty) line count —
  U-1412-2 asserts `last 10 of` prefix wording, not a brittle full-line
  match, so whitespace compaction cannot break the pin.
- `analyzerOffendingPaths` must stay severity-anchored (`^\\s*(error|warning)\\s*-\\s`)
  — the same discipline as `countAnalyzerIssues` (#1035) — so severity words
  inside messages can never fabricate offenders (covered in SC-5 tests).
