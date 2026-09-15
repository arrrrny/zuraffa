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

