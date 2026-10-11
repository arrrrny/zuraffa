# Test List: state A+ upgrade (spec 976)

| Behavior | Criterion | Test file | Red first |
|---|---|---|---|
| 976-prop-compile | SC-1 | test/plugins/state/state_property_compile_test.dart | yes (new suite: sandbox + analyze + driver contract) |
| 976-prop-negative | SC-1 (broken emission fails) | test/plugins/state/state_property_compile_test.dart | yes |
| 976-snapshot | SC-3 | test/plugins/state/state_snapshot_test.dart | yes (goldens absent) |
| 976-json-envelope | SC-2 | test/plugins/state/state_create_json_receipt_test.dart | yes (--json is an input option today) |
| 976-json-receipt | SC-2 | test/plugins/state/state_create_json_receipt_test.dart | yes |
| 976-proof-covers | SC-2 | test/plugins/state/state_create_json_receipt_test.dart | yes |
| 976-make-drift | SC-4 | test/plugins/state/state_make_drift_test.dart | gate (lands + passes) |
| 976-output-schema | order 5 | test/plugins/state/state_output_schema_test.dart | yes |
