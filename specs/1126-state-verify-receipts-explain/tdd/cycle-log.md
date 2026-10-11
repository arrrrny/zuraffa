# TDD Cycle Log: 1126-state-verify-receipts-explain

## RED (recorded before any implementation)

Environment: Dart 3.13.3 stable; targeted suites only.

- `dart test test/plugins/state/state_provenance_test.dart` → RED:
  `Error: Error when reading 'lib/src/plugins/state/state_provenance.dart': No such file or directory` (new API absent).
- `dart test test/plugins/state/state_capability_receipt_test.dart` → RED:
  `Error: Error when reading 'lib/src/plugins/state/state_receipt.dart': No such file or directory` (new API absent).
- `dart test test/plugins/state/state_config_schema_test.dart` → RED:
  `Error: Method not found: 'validateStateConfig'` + configSchema
  property assertions fail against the empty `{}` schema.
- `dart test test/plugins/state/state_explain_test.dart` → RED:
  `--explain` is an unregistered flag — usage refusal, no explain
  block, nothing named isGetting/isGettingList in output.
- `dart test test/plugins/state/state_verify_gate_test.dart` → RED:
  `Could not find a subcommand named "verify" in the "state" command`.

## GREEN

Dart 3.13.3 stable; targeted suites; final run post `dart format .`
(zero residual diff):

- state_provenance_test.dart — 4/4 pass
- state_capability_receipt_test.dart — 5/5 pass
- state_config_schema_test.dart — 7/7 pass
- state_explain_test.dart — 2/2 pass
- state_verify_gate_test.dart — 8/8 pass
- Regression gates: state_create_json_receipt_test 5/5,
  state_make_drift_test 3/3, state_snapshot_test 1/1 (goldens
  re-baselined once for the intentional header emission change),
  state_output_schema_test 2/2, state_builder_test + state_structural
  6/6, state_compile 1/1, state_property_compile 3/3,
  exit_protocol_golden 14/14, dead_positional_grammar 11/11,
  exit_code_sweep_1139 15/15.

Mid-loop discoveries (recorded honestly):

1. `--methods` multi-option returns an EMPTY list (not null) when
   unpassed — the first verify implementation silently silenced the
   receipt contract; fixed + regression-proofed (empty override falls
   through to the receipt).
2. Mutation 1 (flipped digest comparison) SURVIVED the first clean-path
   assertions — SC-1126-o strengthened to assert the match/stale
   classification; mutation then KILLED.
3. The capability path ignored `force`/`dryRun` (pre-existing #876-family
   defect: knobs live in GeneratorOptions) — fixed by deriving builder
   options from capability args; dry-run honesty pinned by SC-1126-c.

Mutation evidence + acceptance coverage: tdd/verification.md.

