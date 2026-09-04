# Tasks: 0970-mock-a-plus-upgrade

- [x] T001. RED: write `test/plugins/mock/mock_command_exit_test.dart` — in-process `zfa mock json` (no entity) must survive and set exitCode 64. Prove red (process killed by bare exit(64)). GREEN: replace `exit(64)` at mock_command.dart with the published-exitCode pattern.
- [x] T002. RED: write `test/plugins/mock/mock_json_output_test.dart` asserting the exact `--json` envelope schema `{files[], actions, fixturesDir, certification, schema:1}` on create/data/json. GREEN: implement the output mode (manual `CreateMockCommand`; flags on data/json).
- [x] T003. RED: write `test/plugins/mock/mock_certification_receipt_test.dart` — `.zfa/receipts/mock-<entity>.json` exists after create with methods-vs-interface, fixture hashes, registry id; `zfa proof check` green fresh / red on hand-edit. GREEN: `MockCertificationService` + `ReceiptStore.saveAs`.
- [x] T004. RED: write `test/plugins/mock/mock_certify_gate_test.dart` — `--certify` fails exit 1 + `--> fix:` on drifted mock, passes on conforming. GREEN: `MockCertifier` gate (structural conformance + scoped dart analyze).
- [x] T005. RED: write `test/plugins/mock/mock_provider_builder_suite_test.dart` — ≥8 behavioral tests for `mock_provider_builder.dart`, all asserting file content. GREEN: suite passes against existing builder behavior (characterization; constraint: do not change generation).
- [x] T006. REFACTOR + VERIFY: dart analyze on touched files; dart test test/plugins/mock/; chunked suite (no new failures); dart format (zero diff).
- [x] T007. Run `/speckit.tdd.verify` → commit `tdd/verification.md` generated fresh from the real run.
- [ ] T008. One PR for the spec (closes #970).
