# Test list — spec 1116 (zfa slice verify: one receipt, five sub-receipts, the merge gate)

File: `test/plugins/slice/slice_receipt_test.dart`

| ID | Lane | Behavior | Test |
| --- | --- | --- | --- |
| R1a | CORE | `zfa slice id <feature-id>` prints the resolved FeatureContract id | slice id (R1) prints the resolved FeatureContract id |
| R1b | CORE | the slice id is stable across re-compositions (compose + compose --force) | slice id (R1) is stable across re-compositions |
| R2 | CORE | compose writes the empty slice.receipt.json skeleton (every section pending) | compose skeleton (R2) |
| R3 | CORE | all five sub-receipts green: verify exits 0, writes the aggregated JSON, prints the one-line status | slice verify aggregation (R3, R7) |
| R4 | CORE | a mutated engine sub-receipt flips verdict red: exit 1, names the violator (entity + mock_class), prints the exact re-run command | slice verify gating (R4, R5) mutated engine sub-receipt |
| R5a | CORE | an entity without a satisfied mock-cert flips cert red: exit 1, uncertified_entities names it, prints `zfa mock certify <entity>` | slice verify gating (R4, R5) uncertified entity |
| R5b | CORE | a missing journal sub-receipt is red: exit 1, names journal, prints `zfa tdd run <id>` | slice verify gating (R4, R5) missing journal |
| R5c | CORE | an xray violation (engine file outside the contract entities) flips xray red: exit 1, violations recorded, prints `zfa slice check <id>` | slice verify gating (R4, R5) xray violation |
| R6a | CORE | the merge gate refuses a red slice: exit 1, "merge gate", points at `zfa slice verify <id>` | merge gate (R6) merge refuses a red slice |
| R6b | CORE | the merge gate passes a green slice: exit 0 | merge gate (R6) merge proceeds when green |
| R7 | CORE | the receipt carries the issue's exact field names (feature_id, generated_at, engine.{status,n_methods,n_mocks_certified}, skin.{status,n_routes,n_contract_rows,n_platforms_audited}, cert.{uncertified_entities,differential_passed}, xray.{layers,violations}, journal.{cycles,violations,final_state}) | asserted inside R3's aggregated-JSON expectations |

Red evidence (pre-implementation): 10/10 failing (`No such file or
directory` on slice.receipt.json; `Unknown slice subcommand: id`).
Green evidence: 10/10 passing — see tdd/verification.md.
