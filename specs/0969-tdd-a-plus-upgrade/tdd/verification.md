# TDD Verification — feature `0969-tdd-a-plus-upgrade`

Generated fresh by `zfa tdd verify --feature 0969-tdd-a-plus-upgrade`.

## Gate

- gate: `not_assessed`
- not_assessed_reason: mutation run timed out: Subprocess TIMED OUT after 4m00s and was killed (SIGKILL): `dart run mutation_test /home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-mutation.xml -f md -o /home/z/my-project/zuraffa/.dart_tool/zfa/tdd-verify-report` (working directory: /home/z/my-project/zuraffa)
   captured output before the kill (tail):
   Found 778 mutations in 7 source files!
lib/src/plugins/tdd/commands/verdicts_command.dart : 25 mutations
File [>                  ]   4% Total [>                  ]   0% (1/778) ~47m 6sFile [=>                 ]   8% Total [>                  ]   0% (2/778) ~48m 11sFile [==>                ]  12% Total [>                  ]   0% (3/778) ~46m 50sFile [===>               ]  16% Total [>                  ]   1% (4/778) ~43m 14sFile [===>               ]  20% Total [>                  ]   1% (5/778) ~41m 39sFile [====>              ]  24% Total [>                  ]   1% (6/778) ~42m 18sFile [=====>             ]  28% Total [>                  ]   1% (7/778) ~43m 7s File [======>            ]  32% Total [>                  ]   1% (8/778) ~43m 27sFile [======>            ]  36% Total [>                  ]   1% (9/778) ~43m 46sFile [=======>           ]  40% Total [>                  ]   1% (10/778) ~44m 15sFile [========>          ]  44% Total [>                  ]   1% (11/778) ~44m 20sFile [=========>         ]  48% Total [>                  ]   2% (12/778) ~44m 38sFile [=========>         ]  52% Total [>                  ]   2% (13/778) ~44m 58sFile [==========>        ]  56% Total [>                  ]   2% (14/778) ~45m 0s File [===========>       ]  60% Total [>                  ]   2% (15/778) ~45m 6s File [============>      ]  64% Total [>                  ]   2% (16/778) ~45m 24sFile [============>      ]  68% Total [>                  ]   2% (17/778) ~45m 31sFile [=============>     ]  72% Total [>                  ]   2% (18/778) ~45m 39sFile [==============>    ]  76% Total [>                  ]   2% (19/778) ~45m 41sFile [===============>   ]  80% Total [>                  ]   3% (20/778) ~45m 29sFile [===============>   ]  84% Total [>                  ]   3% (21/778) ~45m 40sFile [================>  ]  88% Total [>                  ]   3% (22/778) ~45m 12sFile [=================> ]  92% Total [>                  ]   3% (23/778) ~45m 13sFile [==================>]  96% Total [>                  ]   3% (24/778) ~45m 21sFile [===================] 100% Total [>                  ]   3% (25/778) ~45m 25sFAILED: 21/25 (84.00%) mutations were not detected!                               
lib/src/plugins/tdd/commands/verify_command.dart : 151 mutations                  
File [>                  ]   1% Total [>                  ]   3% (26/778) ~45m 1s File [>                  ]   1% Total [>                  ]   3% (27/778) ~44m 40sFile [>                  ]   2% Total [>                  ]   4% (28/778) ~44m 21sFile [>                  ]   3% Total [>                  ]   4% (29/778) ~44m 24sFile [>                  ]   3% Total [>                  ]   4% (30/778) ~44m 29sFile [>                  ]   4% Total [>                  ]   4% (31/778) ~44m 35sFile [>                  ]   5% Total [>                  ]   4% (32/778) ~44m 30sFile [=>                 ]   5% Total [>                  ]   4% (33/778) ~44m 36sFile [=>                 ]   6% Total [>                  ]   4% (34/778) ~44m 38sFile [=>                 ]   7% Total [>                  ]   4% (35/778) ~44m 34sFile [=>                 ]   7% Total [>                  ]   5% (36/778) ~44m 16sFile [=>                 ]   8% Total [>                  ]   5% (37/778) ~44m 11sFile [=>                 ]   9% Total [>                  ]   5% (38/778) ~44m 0s File [=>                 ]   9% Total [>                  ]   5% (39/778) ~44m 1s File [=>                 ]  10% Total [>                  ]   5% (40/778) ~43m 59sFile [==>                ]  11% Total [=>                 ]   5% (41/778) ~43m 54sFile [==>                ]  11% Total [=>                 ]   5% (42/778) ~43m 55sFile [==>                ]  12% Total [=>                 ]   6% (43/778) ~43m 56sFile [==>                ]  13% Total [=>                 ]   6% (44/778) ~43m 52sFile [==>                ]  13% Total [=>                 ]   6% (45/778) ~43m 52sFile [==>                ]  14% Total [=>                 ]   6% (46/778) ~43m 53sFile [==>                ]  15% Total [=>                 ]   6% (47/778) ~43m 52sFile [==>                ]  15% Total [=>                 ]   6% (48/778) ~43m 37sFile [===>               ]  16% Total [=>                 ]   6% (49/778) ~43m 21sFile [===>               ]  17% Total [=>                 ]   6% (50/778) ~43m 4s File [===>               ]  17% Total [=>                 ]   7% (51/778) ~42m 54sFile [===>               ]  18% Total [=>                 ]   7% (52/778) ~42m 43sFile [===>               ]  19% Total [=>                 ]   7% (53/778) ~42m 44sFile [===>               ]  19% Total [=>                 ]   7% (54/778) ~42m 40sFile [===>               ]  20% Total [=>                 ]   7% (55/778) ~42m 41sFile [===>               ]  21% Total [=>                 ]   7% (56/778) ~42m 42sFile [====>              ]  21% Total [=>                 ]   7% (57/778) ~42m 43sFile [====>              ]  22% Total [=>                 ]   7% (58/778) ~42m 41sFile [====>              ]  23% Total [=>                 ]   8% (59/778) ~42m 29sFile [====>              ]  23% Total [=>                 ]   8% (60/778) ~42m 17sFile [====>              ]  24% Total [=>                 ]   8% (61/778) ~42m 6s File [====>              ]  25% Total [=>                 ]   8% (62/778) ~41m 56sFile [====>              ]  25% Total [=>                 ]   8% (63/778) ~41m 58sFile [====>              ]  26% Total [=>                 ]   8% (64/778) ~41m 54sFile [=====>             ]  26% Total [=>                 ]   8% (65/778) ~41m 57sFile [=====>             ]  27% Total [=>                 ]   8% (66/778) ~41m 54s

## Mutation buckets (FR-014)

- killed: 0
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- `A1` — traces: `AC-1`
- `A2` — traces: `AC-2`
- `A3` — traces: `AC-3`
- `A4` — traces: `AC-4`
- `A5` — traces: `AC-5`
- `U1` — traces: `FR-001`
- `U2` — traces: `FR-002`
- `U3` — traces: `FR-003`
- `U4` — traces: `FR-004`
- `U5` — traces: `FR-005`
- `U6` — traces: `FR-006`
- `U7` — traces: `FR-007`
- `U8` — traces: `FR-008`

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 7
- restoration_scope (subjects only, never tests):
  - `/home/z/my-project/zuraffa/lib/src/plugins/tdd/commands/verdicts_command.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/tdd/commands/verify_command.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/tdd/models/verdict_envelope.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/tdd/services/tdd_generation_receipt.dart`
  - `/home/z/my-project/zuraffa/lib/src/plugins/tdd/services/verdict_emitter.dart`
  - `/home/z/my-project/zuraffa/openwiki/cli.md`
  - `/home/z/my-project/zuraffa/openwiki/testing.md`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- preflight_scope_ran (bug #924, per-behavior):
  - `test/plugins/tdd/bug_969_json_verdict_envelope_test.dart`
  - `test/plugins/tdd/bug_969_openwiki_docs_test.dart`
  - `test/plugins/tdd/bug_969_proof_receipts_test.dart`
  - `test/plugins/tdd/verdict_envelope_test.dart`

## Mutation run

- mutation_was_run: false

## Evidence binding (bug #837)

- spec_hash: 722a09026fa4fd8c8f06a7bc8d783f7071654b714ea52d2b7287ec17618c7ab8
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/tdd/commands/verdicts_command.dart` 13bfe9c4897c8c62b7322b86000bb4e276994ffd6ee5613751ce326b1b4125c5
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/tdd/commands/verify_command.dart` d18da3f69193faf7878c68be871630c6350f77c0668f9a5641b892ddf05f8437
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/tdd/models/verdict_envelope.dart` 35e0a9a13f1795ad01492dafcd47fb04406b847249e7294dc88eea69c39a5dfb
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/tdd/services/tdd_generation_receipt.dart` 55d031e5fb046337ec8c787a3a16f5410bcb4dce7bafb3537e3701926addaa34
- subject_hash: `/home/z/my-project/zuraffa/lib/src/plugins/tdd/services/verdict_emitter.dart` 88f7a2f5ab0f3d6e5e01ba4000f3527e28b946b52f0aef056b98566439f3d0f8
- subject_hash: `/home/z/my-project/zuraffa/openwiki/cli.md` 1cd322f1b11830702dd280a4542d55a0cc5e7ce3c018d570503f50496b8eb9da
- subject_hash: `/home/z/my-project/zuraffa/openwiki/testing.md` 7632f4d7c8caa995838c906bfd1e634611b64c3d50e80c9eec3e85f920b780e2
