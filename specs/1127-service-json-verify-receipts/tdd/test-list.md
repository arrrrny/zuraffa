# TDD test list — SPEC 1127 (service: --json, verify, receipts, error handling, --explain)

Behavior → failing-test-first mapping (red → green). Every row's test was
run RED before its implementation, then GREEN after.

| # | Behavior | Test (RED first) |
|---|---|---|
| 1 | `zfa service create <Entity> --json` emits the canonical `zuraffa.verdict.v1` envelope (service class, bound provider, methods, conformance verdict) | `test/plugins/service/service_create_json_verdict_test.dart` |
| 2 | Error paths are envelopes too: missing name → fail + exit 2 + fix; declined generation → skip + exit 1 + fix finding | `service_create_json_verdict_test.dart` |
| 3 | `zfa service verify <Entity>` re-runs the grammar gate; exit 1 on missing_class / missing_method / signature_mismatch / parse_error; `--json` envelope | `test/plugins/service/service_verify_command_test.dart` |
| 4 | Knobs resolve receipt-first, flags override | `service_verify_command_test.dart` |
| 5 | `CreateServiceCapability.execute()` writes the deterministic `.zfa/receipts/service-<entity>.json` proof.v1 receipt (digests + ledger) | `test/plugins/service/service_receipt_test.dart` |
| 6 | Dry runs and skipped runs never write a lying receipt; `--force` refreshes latest-wins | `service_receipt_test.dart` |
| 7 | The entire `execute()` path is guarded: malformed entity → `ExecutionResult(success:false)`, CLI → structured verdict, never an uncaught exception | `test/plugins/service/service_error_handling_test.dart` |
| 8 | `--explain` describes shape/provider binding/methods without generating; `--explain --json` → skip envelope | `test/plugins/service/service_explain_test.dart` |
| 9 | `VerdictEnvelope.fromJson` parses `zuraffa.verdict.v1`, throws loudly on unknown schema, round-trips | `test/core/verdict_envelope_test.dart` |
| 10 | Schema ≡ grammar treaty intact (parity suite green; `--explain` classified as a non-knob output flag) | `test/plugins/service/service_schema_grammar_parity_test.dart` |
| 11 | #1096 chdir-window race suite keeps its guarantees under the migrated invocation vehicle | `test/commands/cli_runner_cwd_race_test.dart` |
