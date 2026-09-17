# Cycle Log — 1535 tdd-profile `single:` template parsing

Baseline entry (tdd.plan): 8 behaviors planned (7 unit, 1 acceptance) in
./test-list.md, all PENDING. Engine: LLM-guided fallback (zfa binary
unavailable on this machine — `zfa --version` → not found, no `.zfa.json`).

## Baseline

- suite: `dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart` (fast tier) — no test file yet (RED-by-absence at plan time)
- at: 2026-09-15T17:29:20Z

## Cycle: B-001..B-008 (RED — pre-fix proof)

- kind: red (test-first)
- at: 2026-09-15 (commit before fix)
- command: `dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart --preset=all`
- result: **+2 passed / −7 failed** — the two pre-existing-contract guards pass
  (single-quoted verbatim, legacy bullet normalization); every bug behavior RED:
  - Keys-block `single: "…\"{name}\""` → loaded template contains literal `\"`
    (actual: `dart test {file} --plain-name \\"{name}\\"`) — issue case 2 root defect.
  - frontmatter form → same literal-`\"` defect.
  - `file:`/`suite:` double-quoted values → same literal-`\"` defect.
  - `<test name>` profile → loader returns the broken template SILENTLY
    (actual: `dart test {file} --plain-name \"<test name>\"`) instead of rejecting
    at load — issue case 1 root defect (bullet path likewise).
  - E2E honest red (slow tier) → loader assertion fails first (template carries
    `\"`); downstream this is the exit-79 runner-error misclassification.
- classification: red proven for the right reason (assertions target the
  unescape + load-time rejection contract from the issue's acceptance criteria).


## Cycle: GREEN (fix applied) + re-verification — 2026-09-16 session

- kind: green + refactor-clear
- at: 2026-09-16 (fix in working tree on top of the red commit)
- fix: parser-only change in
  `lib/src/plugins/tdd/services/runner.dart` — `_matchQuotedScalar` now
  reports the quote style; `_yamlUnescapeDoubleQuoted` + `_hexCodePointAt`
  implement the YAML 1.2 §5.7 double-quoted escape table;
  `_prepareSingleScalar` / `_prepareFileScalar` / `_prepareSuiteScalar`
  post-process each extracted scalar; AC-2 unknown-placeholder rejection
  runs after legacy normalization in the `single:` lane (incl. the bullet).
- commands + results (ALL real, this session):
  - RED re-proof: fix stashed →
    `dart test test/plugins/tdd/bug_1535_profile_template_parsing_test.dart --preset=all`
    → `00:02 +2 -7: Some tests failed.` (all 7 bug behaviors red; the 2 AC-4
    guards green pre-fix — red for the right reason)
  - GREEN: fix restored → same command → `00:09 +9: All tests passed!`
    (slow AC-3 e2e included: honest red → `RedClassification.assertion`,
    testCount == 1)
  - fast tier → `+8: All tests passed!`
  - `dart analyze` (changed files) → `No issues found!`
  - `dart format` (changed files) → `0 changed`
- mutation checks:
  - whole-fix-removal mutant → 7/7 behaviors failed (the RED re-proof)
  - targeted AC-2 mutant (`if (false && unknown.isNotEmpty)`) →
    `00:02 +6 -2` — killed by exactly the two AC-2 behaviors; reverted,
    re-verified green
- regression:
  - `dart test test/plugins/tdd/services/` → `01:16 +1120 -10`; the 10
    failures (refactor_passes_test.dart, isolate `FormatException:
    Unexpected extension byte`) are pre-existing on this machine — proven
    identical with the fix stashed
  - runner-adjacent top-level suites → `+20: All tests passed!`
- classification: green proven on the same assertions that were red; no
  test loosened; full gate audit in ./verification.md → PASS
