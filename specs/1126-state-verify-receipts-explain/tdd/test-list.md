# Test List: 1126-state-verify-receipts-explain

One behavior per line, traced to the acceptance criteria in spec.md.

| Behavior | Criterion | Test file | Red first |
|---|---|---|---|
| 1126-provenance-header | AC-4 / SC-5 | test/plugins/state/state_provenance_test.dart | yes (no header today) |
| 1126-provenance-both-modes | AC-4 / SC-5 | test/plugins/state/state_provenance_test.dart | yes (entity + custom branches) |
| 1126-provenance-deterministic | SC-5 (byte-identity gates survive) | test/plugins/state/state_provenance_test.dart | gate (regenerated goldens) |
| 1126-receipt-stable-name | AC-3 / SC-2 | test/plugins/state/state_capability_receipt_test.dart | yes (no stable receipt today) |
| 1126-receipt-bindings | AC-3 / SC-2 (state_sha256 + entity_source) | test/plugins/state/state_capability_receipt_test.dart | yes |
| 1126-receipt-capability-guarded | SC-2 (execute never crashes through the boundary) | test/plugins/state/state_capability_receipt_test.dart | yes |
| 1126-receipt-dry-run | SC-2 (dry runs never persist proofs) | test/plugins/state/state_capability_receipt_test.dart | yes |
| 1126-receipt-cli-path | AC-3 (.zfa/receipts/state-<entity>.json after zfa state create) | test/plugins/state/state_capability_receipt_test.dart | yes |
| 1126-receipt-regen-latest-wins | SC-2 (refresh in place) | test/plugins/state/state_capability_receipt_test.dart | yes |
| 1126-schema-vocabulary | AC-5 / SC-4 | test/plugins/state/state_config_schema_test.dart | yes (empty {} today) |
| 1126-schema-unknown-key | AC-5 | test/plugins/state/state_config_schema_test.dart | yes |
| 1126-schema-wrong-type | AC-5 | test/plugins/state/state_config_schema_test.dart | yes |
| 1126-schema-empty-refusal | AC-5 (the #1122 refusal) | test/plugins/state/state_config_schema_test.dart | yes |
| 1126-schema-capability-refusal | AC-5 (JSON args are the unknown-key surface) | test/plugins/state/state_config_schema_test.dart | yes |
| 1126-explain-block | AC-2 / SC-3 | test/plugins/state/state_explain_test.dart | yes (no --explain today) |
| 1126-explain-no-write | AC-2 (describe, never generate) | test/plugins/state/state_explain_test.dart | yes |
| 1126-explain-derivation-map | AC-2 (each method → state member) | test/plugins/state/state_explain_test.dart | yes |
| 1126-explain-json | SC-3 (envelope explain block, verdict skip) | test/plugins/state/state_explain_test.dart | yes |
| 1126-verify-clean | AC-1 / SC-1 (exit 0) | test/plugins/state/state_verify_gate_test.dart | yes (no verify verb today) |
| 1126-verify-modified | AC-1 (hand-edited bytes → exit 1 + --> fix:) | test/plugins/state/state_verify_gate_test.dart | yes |
| 1126-verify-stale-entity | AC-1 (entity changed → exit 1) | test/plugins/state/state_verify_gate_test.dart | yes |
| 1126-verify-missing-method | AC-1 (member absent → exit 1) | test/plugins/state/state_verify_gate_test.dart | yes |
| 1126-verify-missing-receipt | AC-1 (no receipt → exit 1 + fix) | test/plugins/state/state_verify_gate_test.dart | yes |
| 1126-verify-json | AC-1 (canonical envelope, last stdout line) | test/plugins/state/state_verify_gate_test.dart | yes |
| 1126-verify-usage | AC-1 (no entity → exit 2) | test/plugins/state/state_verify_gate_test.dart | yes |
| 976-json-envelope-regression | SC-6 (do not break --json) | test/plugins/state/state_create_json_receipt_test.dart | gate (must stay green) |
| 976-timestamped-receipt-regression | SC-6 (issue #1138 receipt additive-kept) | test/plugins/state/state_create_json_receipt_test.dart | gate (must stay green) |
| 976-make-drift-regression | SC-5/SC-6 (create ≡ make) | test/plugins/state/state_make_drift_test.dart | gate (must stay green) |
| 976-snapshot-regression | SC-5/SC-6 (goldens) | test/plugins/state/state_snapshot_test.dart | gate (regenerated once) |
