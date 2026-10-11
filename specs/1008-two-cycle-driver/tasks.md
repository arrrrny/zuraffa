# Tasks: 1008-two-cycle-driver

| id | task | status |
| -- | ---- | ------ |
| T-01 | Write the RED test suite (two_cycle_run_commands_test.dart, feature 004-login-ui) and prove every test fails for the right reason (commands not found) | done |
| T-02 | Lane resolution service: row tags in TestListReader + plan-file reader (04-ENGINE.md / 04-SKIN.md) with CORE default | done |
| T-03 | Lane receipts service: write/read 04-engine-receipt.json + 04-skin-receipt.json + unified journal entry | done |
| T-04 | Extract the shared RunDriverCore from RunCommand (behavior-preserving move; RunCommand keeps its constructor and arg surface) | done |
| T-05 | RunEngineCommand (`zfa tdd run-engine`) — engine lane + receipt + lane summary | done |
| T-06 | RunSkinCommand (`zfa tdd run-skin`) — engine-receipt gate (exit 2) + skin lane + receipt + lane summary | done |
| T-07 | RunCommand becomes the meta-driver — chain lanes, fail fast, unified journal entry, legacy byte-compat | done |
| T-08 | StatusCommand (`zfa tdd status`) — one-line two-lane verdict | done |
| T-09 | Register the commands in tdd_command.dart; update command docs (description, CLI_GUIDE) | done |
| T-10 | GREEN: full new suite + the existing 40-test run suite + dart analyze + chunked fast suite + dart format | done |
| T-11 | tdd/verification.md from the REAL runs; cycle-log evidence | done |
