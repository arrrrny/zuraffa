# Test List — 972-usecase-aplus-upgrade

All tests live under `test/plugins/usecase/` (fast tier — they run with
plain `dart test test/plugins/usecase/`, no slow tag).

| ID | Behavior | Test file | Status |
|---|---|---|---|
| FR1-1 | bare `zfa usecase` run() exits 64, prints subcommand grammar, never the dead hint, never generates (subprocess probe) | `usecase_command_grammar_test.dart` | DONE |
| FR1-2 | dispatch rejects a bare entity name before run() (runner contract unchanged) | `usecase_command_grammar_test.dart` | DONE |
| FR1-3 | no-args invocation reports the missing subcommand at dispatch level | `usecase_command_grammar_test.dart` | DONE |
| FR2-1 | fresh `create --json` emits `{schema:1, methods:[{name,action}]}`, verdict order preserved | `usecase_create_json_test.dart` | DONE |
| FR2-2 | idempotent re-run reports `skipped`/`already` verdicts, exit 0 | `usecase_create_json_test.dart` | DONE |
| FR2-3 | guard-dropped method → `skipped` + `interface_missing_method:Class.method` reason, in envelope AND receipt | `usecase_create_json_test.dart` | DONE |
| FR2-4 | missing entity name → usage error, exit 64 | `usecase_create_json_test.dart` | DONE |
| FR3-1 | receipt at `.zfa/receipts/usecase-<entity>.json` (proof.v1): requested/generated/skipped + guard reason codes + digests | `usecase_create_json_test.dart` | DONE |
| FR3-2 | `zfa proof check` verifies the fresh receipt green (`"ok":true`) | `usecase_create_json_test.dart` | DONE |
| FR4-neg | repository muted by `--use-service`: same-plan misfire FAILS make (exit 1 + `--> fix: zfa repository create Task --methods=...`, no `✅ Done.`) | `usecase_expectation_post_pass_test.dart` | DONE |
| FR4-pos | service-in-plan declares requested methods → make succeeds, usecases compile against a real interface | `usecase_expectation_post_pass_test.dart` | DONE |
| FR4-scope | usecase-only run (repository NOT in plan) keeps the pre-existing fail-open contract — no post-pass failure | `usecase_expectation_post_pass_test.dart` | DONE |
| FR5-1 | `usecase create` default set is `[get, update]` — no toggle usecase file, envelope requested set honest | `usecase_toggle_default_test.dart` | DONE |
| FR5-2 | make flow default requests no toggle — even though the repository interface (its own default vocabulary) declares it | `usecase_toggle_default_test.dart` | DONE |
| FR5-3 | explicit `--methods=get,toggle` still generates toggle (explicit request honored, guard permitting) | `usecase_toggle_default_test.dart` | DONE |
| FR6-rev | create then revert deletes files, reports `deleted` verdicts, ships no receipt; create receipt outlives artifacts and `proof check` reports them deleted | `usecase_revert_test.dart` | DONE |
| FR6-rev2 | reverting with nothing generated is a quiet success (`skipped` verdicts, exit 0) | `usecase_revert_test.dart` | DONE |
| FR6-app | existing class gains `execute` — verdict `appended` (not created), file keeps its shell | `usecase_stream_append_test.dart` | DONE |
| FR6-str | stream method (watch) created on first request, `skipped` as already-present on re-run | `usecase_stream_append_test.dart` | DONE |

Regression coverage retained (pre-existing suites, still green):

- `test/plugins/usecase/entity_usecase_generator_test.dart` — #921
  guard filter behavior (drop against existing interface, fail-open when
  absent, keep when declared).
- `test/plugins/usecase/usecase_plugin_test.dart` — custom /
  orchestrator / polymorphic / stream generation unchanged.
- `test/commands/make_receipt_test.dart` — make receipt contract.
- `test/commands/dead_positional_grammar_test.dart` — the other nine
  commands' #856 contract.
