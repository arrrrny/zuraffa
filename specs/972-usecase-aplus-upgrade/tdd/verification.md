# TDD Verification Report: usecase A+ upgrade

**Feature**: 972-usecase-aplus-upgrade
**Verified**: 2026-09-05
**Mode**: LLM-guided audit via the `speckit.tdd.verify` fallback path
(the zuraffa repo root carries no `.zfa.json`, so the command's Step 0
engine detection resolves `ZFA_MISSING` → original audit: red-phase
evidence, mutation spot-audit on the changed files,
acceptance-criteria coverage). All evidence below is from REAL runs;
commands are quoted verbatim.

---

## Verdict: **PASS**

19/19 spec-972 behaviors covered by passing tests under
`test/plugins/usecase/` (fast tier); the full fast suite (67 chunks)
passes with zero regressions attributable to this change; the
mutation spot-audit is 3/3 killed after one suite strengthening pass.

---

## Acceptance Criteria Coverage

| AC | Requirement | Proving test(s) | Evidence |
|---|---|---|---|
| AC-1 | Bare `zfa usecase` exits 64 with usage (regression test) | `usecase_command_grammar_test.dart` FR1-1 | Subprocess probe asserts exit **64**, `<subcommand>` in stdout, dead hint absent, no generation. **PROVED** |
| AC-2 | `--json` envelope asserted by test; receipt written and proof-checkable | `usecase_create_json_test.dart` (4 tests) | Envelope `{schema:1, methods:[...]}` parsed and field-asserted; receipt at `.zfa/receipts/usecase-<entity>.json` with requested/generated/skipped + guard codes + digests; `zfa proof check --format=json` → `"ok":true` on the fresh workspace. **PROVED** |
| AC-3 | Same-plan misfire FAILS make with `--> fix:` line — tested both ways | `usecase_expectation_post_pass_test.dart` | Negative: `make Task repository usecase --use-service` → output contains `fix: zfa repository create Task`, `exitCode == 1`, no `✅ Done.`. Positive: `make Chat service usecase --service=ChatService --methods=get,update` → exit 0, `chat_service.dart` declares `get(`/`update(`, usecases emitted. Scope pin: usecase-only run stays fail-open (no false failure). **PROVED** |
| AC-4 | No entity gets toggle without explicit request | `usecase_toggle_default_test.dart` (3 tests) | Create path: default envelope `[get, update]`, no toggle file. Make path: no toggle usecase even though the repository interface (its own default vocabulary) declares `toggle(`. Explicit `--methods=get,toggle` still honored. **PROVED** |

---

## Test Coverage Summary

| Category | Total | DONE | PENDING | BLOCKED |
|---|---|---|---|---|
| FR-1 grammar (3) | 3 | 3 | 0 | 0 |
| FR-2 --json verdicts (4) | 4 | 4 | 0 | 0 |
| FR-3 receipts/proof (2) | 2 | 2 | 0 | 0 |
| FR-4 expectation post-pass (3) | 3 | 3 | 0 | 0 |
| FR-5 toggle default (3) | 3 | 3 | 0 | 0 |
| FR-6 revert / stream-append (4) | 4 | 4 | 0 | 0 |
| **Total** | **19** | **19** | **0** | **0** |

Retained regression suites (still green): `entity_usecase_generator_test.dart`
(#921 guard), `usecase_plugin_test.dart`, `make_receipt_test.dart`,
`dead_positional_grammar_test.dart`.

---

## Red-Phase Evidence (test-first discipline)

The suite was written before any production change and run against
master: **9 failing tests**, including the exact issue symptoms —

```
Expected: <64>
  Actual: <0>
  a bare-command usage error must not look successful (silent no-op).
  stdout=❌ Usage: zfa usecase <EntityName> [options]
```

Full detail in `tdd/cycle-log.md` (cycle 1). The pre-fix code is
itself the surviving-mutant set; every red assertion was then killed
by the implementation (cycle 2: `dart test test/plugins/usecase/` →
`+36: All tests passed!`).

---

## Mutation Spot-Audit (changed files)

Post-green mutants, each applied, run, and reverted (restoration
verified via `dart analyze` + re-run green):

| Mutant | Change | Run | Verdict |
|---|---|---|---|
| M-1 | `usecase_command.dart` run(): subcommand usage → dead hint, exit 0 (the master behavior) | `dart test test/plugins/usecase/usecase_command_grammar_test.dart` | **KILLED** — `Expected: <64> Actual: <0>` |
| M-2 | `usecase_plugin.dart:124` default `['get','update']` → `['get','update','toggle']` | `dart test test/plugins/usecase/usecase_toggle_default_test.dart` | First run: **SURVIVED** (create-path only). Suite strengthened with the make-flow test; re-run: **KILLED** — `make flow: the default method set requests no toggle … [E]` |
| M-3 | `make_command.dart` `_verifyUsecaseExpectations` short-circuits to `const []` (post-pass disabled) | `dart test test/plugins/usecase/usecase_expectation_post_pass_test.dart` | **KILLED** — `FR-4 negative … [E]` |

Mutation score for the audited scope: **3/3 killed** (after one
documented strengthening pass — the surviving mutant was the audit
working as intended).

---

## Full-Suite Regression Evidence

- `dart test test/plugins/usecase/` → **+37: All tests passed!**
- `dart test test/commands/` → **+135: All tests passed!**
- Whole fast tier, chunked (`tools/run_tests_chunked.sh` chunk set, run
  one chunk at a time): **63 chunks PASS**; the only 4 non-passing
  chunks (`test/benchmark`, `test/core/dependencies`,
  `test/integration`, `test/plugins/tdd/scenarios`) are fully
  slow-tagged folders that run **zero** tests in the fast tier
  ("No tests ran / tag selectors") — a pre-existing tag-exclusion
  artifact, identical on master.
- Targeted slow-tier runs that touch this change:
  `make_receipt_test.dart` (2/2), `toggle_method_test.dart` (uses
  explicit `--methods=['get','toggle']` — unaffected),
  `custom_usecase_detection_test.dart` (4/4),
  `issue_410`/`issue_419` regression tests (8/8),
  receipt/proof suites (23/23), `append_mode_test.dart` (1/1).
- `test/integration/full_entity_workflow_test.dart` fails with
  `[conflict] Multiple operations for lib/src/di/index.dart` —
  verified **identical on pristine master** (git stash comparison),
  i.e. pre-existing, not caused by this change.

## Static Analysis / Formatting

- `dart analyze` (touched files): **No issues found!**
- `dart analyze` (full project): 0 errors, 0 warnings (345
  pre-existing `info`-level lints, repo-wide).
- `dart format .`: **0 changed** — zero remaining formatting diffs.

---

## Implementation Map (where each FR lives)

- FR-1: `lib/src/commands/usecase_command.dart` (run() →
  `reportSubcommandUsage()`); probe case in
  `test/commands/fixtures/plugin_run_probe.dart`.
- FR-2: `lib/src/commands/usecase_create_command.dart` (envelope, exit
  codes); verdict model in
  `lib/src/plugins/usecase/usecase_verdicts.dart`; per-method verdicts
  in `lib/src/plugins/usecase/generators/entity_usecase_generator.dart`
  (`generateWithVerdicts`).
- FR-3: receipt writing in `usecase_create_command.dart`
  (`.zfa/receipts/usecase-<entity>.json`, `proof.v1`).
- FR-4: structured guard in
  `lib/src/utils/source_interface_guard.dart` (`evaluate()` /
  `interfaceAbsent`); expectation recording in
  `usecase_plugin.dart` (`generateWithContext`); post-pass in
  `lib/src/plugins/usecase/usecase_expectation_post_pass.dart`; hook in
  `make_command.dart` (`_verifyUsecaseExpectations`).
- FR-5: `usecase_plugin.dart:124` default `['get','update']`;
  `usecase_create_command.dart` same default.

## Remediation Tasks

None — no surviving mutants, no pending behaviors.
