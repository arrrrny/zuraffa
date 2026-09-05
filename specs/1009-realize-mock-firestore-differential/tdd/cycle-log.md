# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 1009-realize-mock-firestore-differential (red)

- behavior: 1009-realize-mock-firestore-differential
- kind: red
- era: MOCKED
- criterion: SC-1..SC-3
- test: zfa tdd realize-mock Login --against=firestore (public CLI)
- command: `dart run bin/zfa.dart tdd realize-mock Login --against=firestore`
- exit: 64
- at: 2026-09-05T00:27:52.468019Z
- output:
```
ERROR: Could not find an option named "--against".
Usage: zfa tdd <subcommand> [options]

(Real transcript, this session, before implementation: the realize-mock
verb did not exist — no Tier2MockProvider, no FakeFirebaseFirestore, no
differential receipt writer anywhere in lib/. Exit code 64.)
```
- schema: 1
- prev-hash: genesis
- hash: 8be1e4a59f8a3394120c896bddfdd72c9ffb1cea9d4cbcb58eea8d134386c13f

## Cycle: 1009-realize-mock-firestore-differential (green)

- behavior: 1009-realize-mock-firestore-differential
- kind: green
- era: MOCKED
- criterion: SC-1..SC-3
- test: realize_mock_command_test.dart (44 new tests) + end-to-end production run
- command: `dart run bin/zfa.dart tdd realize-mock Login --against=firestore --project <scratch>`
- exit: 0
- at: 2026-09-05T00:27:52.477236Z
- output:
```
zfa tdd realize-mock: entity Login -> against firestore
   feature: 1009-demo
   tier-1 contract test: 1 file(s) (test/login_contract_test.dart)
   tier-1 contract test green (exit 0)
   method getAllLogins   diff=none
   method getById        diff=none
   method saveLogin      diff=none
   receipt: .zfa/receipts/realize.Login.firestore.receipt.json
     (3 method record(s), verdict certified)
realize-mock: entity=Login against=firestore feature=1009-demo
   methods=3 mismatch=0 result=certified

Real evidence, this session: 44/44 new tests green; 75/75 chunked
fast-tier chunks (71 PASS / 4 by-design SKIP / 0 FAIL); 4/4 deliberate
mutants killed with byte-exact restoration; zfa proof check parsed the
receipt (1 receipt, 0 findings, OK); the wrong-type divergence run
(seed 42.0 vs oracle 42) exited 1 naming getById.
```
- schema: 1
- prev-hash: 8be1e4a59f8a3394120c896bddfdd72c9ffb1cea9d4cbcb58eea8d134386c13f
- hash: 1447dda813a7de4ec4606ee89b61fc5734f154055fae11dda1db8ab29ca2e6e6

