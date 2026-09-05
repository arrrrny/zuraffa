# TDD Verification — feature `0970-mock-a-plus-upgrade`

Generated fresh by `zfa tdd verify --feature 0970-mock-a-plus-upgrade`.

## Gate

- gate: `not_assessed`
- not_assessed_reason: mutation run timed out: Subprocess TIMED OUT after 6m00s and was killed (SIGKILL): `dart run mutation_test /home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-mutation.xml -f md -o /home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-report` (working directory: /home/z/my-project/zuraffa)
   captured output before the kill (tail):
   Found 656 mutations in 5 source files!
lib/src/commands/mock_command.dart : 202 mutations
File [>                  ]   0% Total [>                  ]   0% (1/656) ~39m 38sFile [>                  ]   1% Total [>                  ]   0% (2/656) ~54m 48sFile [>                  ]   1% Total [>                  ]   0% (3/656) ~49m 25sFile [>                  ]   2% Total [>                  ]   1% (4/656) ~54m 19sFile [>                  ]   2% Total [>                  ]   1% (5/656) ~51m 9s File [>                  ]   3% Total [>                  ]   1% (6/656) ~49m 4s File [>                  ]   3% Total [>                  ]   1% (7/656) ~47m 17sFile [>                  ]   4% Total [>                  ]   1% (8/656) ~45m 35sFile [>                  ]   4% Total [>                  ]   1% (9/656) ~44m 41sFile [>                  ]   5% Total [>                  ]   2% (10/656) ~47m 2sFile [=>                 ]   5% Total [>                  ]   2% (11/656) ~48m 42sFile [=>                 ]   6% Total [>                  ]   2% (12/656) ~50m 18sFile [=>                 ]   6% Total [>                  ]   2% (13/656) ~49m 21sFile [=>                 ]   7% Total [>                  ]   2% (14/656) ~48m 31sFile [=>                 ]   7% Total [>                  ]   2% (15/656) ~49m 13sFile [=>                 ]   8% Total [>                  ]   2% (16/656) ~50m 8s File [=>                 ]   8% Total [>                  ]   3% (17/656) ~50m 49sFile [=>                 ]   9% Total [>                  ]   3% (18/656) ~50m 0s File [=>                 ]   9% Total [>                  ]   3% (19/656) ~50m 45sFile [=>                 ]  10% Total [>                  ]   3% (20/656) ~51m 23sFile [=>                 ]  10% Total [>                  ]   3% (21/656) ~52m 26sFile [==>                ]  11% Total [>                  ]   3% (22/656) ~51m 42sFile [==>                ]  11% Total [>                  ]   4% (23/656) ~52m 22sFile [==>                ]  12% Total [>                  ]   4% (24/656) ~52m 58sFile [==>                ]  12% Total [>                  ]   4% (25/656) ~53m 25sFile [==>                ]  13% Total [>                  ]   4% (26/656) ~53m 45sFile [==>                ]  13% Total [>                  ]   4% (27/656) ~54m 3s File [==>                ]  14% Total [>                  ]   4% (28/656) ~54m 24sFile [==>                ]  14% Total [>                  ]   4% (29/656) ~53m 38sFile [==>                ]  15% Total [>                  ]   5% (30/656) ~54m 2s File [==>                ]  15% Total [>                  ]   5% (31/656) ~54m 20sFile [===>               ]  16% Total [>                  ]   5% (32/656) ~54m 37sFile [===>               ]  16% Total [>                  ]   5% (33/656) ~54m 56sFile [===>               ]  17% Total [>                  ]   5% (34/656) ~55m 15sFile [===>               ]  17% Total [=>                 ]   5% (35/656) ~55m 21sFile [===>               ]  18% Total [=>                 ]   5% (36/656) ~55m 35sFile [===>               ]  18% Total [=>                 ]   6% (37/656) ~54m 53sFile [===>               ]  19% Total [=>                 ]   6% (38/656) ~55m 2s File [===>               ]  19% Total [=>                 ]   6% (39/656) ~55m 18sFile [===>               ]  20% Total [=>                 ]   6% (40/656) ~55m 26sFile [===>               ]  20% Total [=>                 ]   6% (41/656) ~55m 34sFile [===>               ]  21% Total [=>                 ]   6% (42/656) ~55m 43sFile [====>              ]  21% Total [=>                 ]   7% (43/656) ~55m 54sFile [====>              ]  22% Total [=>                 ]   7% (44/656) ~56m 4s File [====>              ]  22% Total [=>                 ]   7% (45/656) ~56m 11sFile [====>              ]  23% Total [=>                 ]   7% (46/656) ~56m 21sFile [====>              ]  23% Total [=>                 ]   7% (47/656) ~56m 28sFile [====>              ]  24% Total [=>                 ]   7% (48/656) ~55m 56sFile [====>              ]  24% Total [=>                 ]   7% (49/656) ~56m 1s File [====>              ]  25% Total [=>                 ]   8% (50/656) ~56m 3s File [====>              ]  25% Total [=>                 ]   8% (51/656) ~55m 34sFile [====>              ]  26% Total [=>                 ]   8% (52/656) ~55m 6s File [====>              ]  26% Total [=>                 ]   8% (53/656) ~54m 41sFile [=====>             ]  27% Total [=>                 ]   8% (54/656) ~54m 47sFile [=====>             ]  27% Total [=>                 ]   8% (55/656) ~54m 21sFile [=====>             ]  28% Total [=>                 ]   9% (56/656) ~53m 56sFile [=====>             ]  28% Total [=>                 ]   9% (57/656) ~53m 33sFile [=====>             ]  29% Total [=>                 ]   9% (58/656) ~53m 7s File [=====>             ]  29% Total [=>                 ]   9% (59/656) ~52m 42sFile [=====>             ]  30% Total [=>                 ]   9% (60/656) ~52m 16sFile [=====>             ]  30% Total [=>                 ]   9% (61/656) ~51m 54sFile [=====>             ]  31% Total [=>                 ]   9% (62/656) ~51m 57sFile [=====>             ]  31% Total [=>                 ]  10% (63/656) ~51m 59sFile [======>            ]  32% Total [=>                 ]  10% (64/656) ~52m 2s File [======>            ]  32% Total [=>                 ]  10% (65/656) ~52m 6s File [======>            ]  33% Total [=>                 ]  10% (66/656) ~51m 45s

## Mutation buckets (FR-014)

- killed: 0
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- `A1` — traces: `AC-1`
- `A1b` — traces: `AC-1`
- `A2` — traces: `AC-2`
- `A3a` — traces: `AC-2`
- `A3b` — traces: `AC-2`
- `A2b` — traces: `AC-2`
- `A4` — traces: `AC-3`
- `A4b` — traces: `AC-3`
- `A5` — traces: `AC-3`
- `A5b` — traces: `AC-3`
- `A6` — traces: `AC-4`
- `A7` — traces: `AC-4`
- `U6` — traces: `FR-004`
- `U5` — traces: `FR-004`
- `A8` — traces: `AC-5`
- `U7` — traces: `FR-005`
- `U8` — traces: `FR-005`
- `U1` — traces: `FR-001`
- `U2` — traces: `FR-002`
- `U3` — traces: `FR-003`
- `U4` — traces: `FR-003`

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 5
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/lib/src/commands/mock_command.dart`
  - `/home/z/my-project/zuraffa/lib/src/core/project/receipt_store.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/mock/builders/mock_provider_builder.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/mock/mock_plugin.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/mock/services/mock_certification.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- preflight_scope_ran (bug #924, per-behavior):
  - `test/plugins/mock/mock_certification_receipt_test.dart`
  - `test/plugins/mock/mock_certify_gate_test.dart`
  - `test/plugins/mock/mock_command_exit_test.dart`
  - `test/plugins/mock/mock_json_output_test.dart`
  - `test/plugins/mock/mock_provider_builder_suite_test.dart`

## Mutation run

- mutation_was_run: false

## Evidence binding (bug #837)

- spec_hash: 4bd99f8c0b257947c8012dbe48cd1b02c53b03db200822099c39d302af2d61d6
- subject_hash: `/home/z/my-project/zuraffa/lib/src/commands/mock_command.dart` 2b6f2fba72e3ce74b1a864bba35b68938b2846f4f387698e2c90341157deae83
- subject_hash: `/home/z/my-project/zuraffa/lib/src/core/project/receipt_store.dart` 3db50bc388b750e9cf2f8b80f3e163141bff9cb2b4687f80c9826eb0b944c6e7
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/mock/builders/mock_provider_builder.dart` 8d5667801d5ef44214de4ee134cd8de055b07cee177d466613a36869562a1aa8
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/mock/mock_plugin.dart` 6512ee02961fd8e2fd834aa8188f8c952184c3a4a2452d7a6e8a9b285372e8d8
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/mock/services/mock_certification.dart` fe1cea3197a3a8d2100fc59a30317ba7657588b5093e03a41107d0f02637153d
