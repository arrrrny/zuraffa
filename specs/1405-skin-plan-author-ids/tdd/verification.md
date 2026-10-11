# Verification: 1405 — skin plan author strict W-ids + plan validator

**Branch**: `feat/1405-skin-plan-author-ids` | **Date**: 2026-09-10
**Toolchain**: Dart 3.13.3 (stable), Linux x64

## Test-first evidence (red → green)

### RED (recorded against the unfixed tree — see [red-evidence.txt](./red-evidence.txt))

- `test/plugins/tdd/services/skin_plan_author_test.dart`: load error — the
  `SkinPlanAuthor` contract did not exist (0 passed / 1 load error).
- `test/plugins/tdd/commands/issue_1405_skin_plan_author_ids_test.dart`:
  **3 passed / 5 failed**. The five failures are exactly the new contract
  rows:
  - A-1405-1 (×2): the sanitizable tokens leaked prose into the id column
    (`| W1 (renders the login screen pixel-perfect | skin behavior declared
    in ## Lanes |` — the issue's malformed row shape).
  - A-1405-2 (×3): the malformed declaration planned exit 0 and WROTE
    `04-SKIN.md` — the malformed table was ingested (the bug).
- Green-by-design regression guards (pinned pre-fix, stayed green after):
  A-1405-3 (clean `W1-W9` → nine rows), A-1405-4 (canonical #1000 fixture),
  U-1405-6 (CORE annotations unchanged).

### GREEN (post-fix, same session)

| Suite | Result |
| --- | --- |
| `test/plugins/tdd/services/skin_plan_author_test.dart` | **20/20 passed** |
| `test/plugins/tdd/commands/issue_1405_skin_plan_author_ids_test.dart` | **8/8 passed** |
| Lane/plan regression set (plan_lanes_1000, plan_skin_contract_1004, bug_1366, issue_1309, bug_1432, lane_split_platform_rows, bug_1141, split_command_1000, bug_1365, bug_1261, run_skin_command) | **59/59 passed** |
| Plan-touching set (plan_unbound_traces_1319, contract_kind_1007, bug_1140, bug_846, bug_993, test_list_reader, sc_018 e2e, 078-skin-contract-schema u4) | **68/68 passed** |

ACTUAL total: **155 passed / 0 failed** across the touched surface. No
pre-existing failures were observed in the suites above (verified against a
stashed tree when `plan_skin_contract_1004` initially caught a real design
regression — the derived-`A`-ids-in-SKIN routing form — which was fixed by
scoping the strict W grammar to non-derived hand tokens before commit).

## Required plan-time validator checks (task protocol §5, end-to-end CLI)

Script: `scripts/e2e_1405_check.sh` (hermetic temp project, ACTUAL exit codes):

1. **Malformed ids rejected**: the issue's exact declaration
   (`Sign In header and subtitle, W1 (renders the login screen pixel-perfect,
   W2, a full-width guest outline button, an or divider`) →
   `exit_code=2`, three refusal lines each naming the token, the
   malformation class (`carries no W<digits> pattern`), and the `--> fix:`
   remedy; `04-SKIN.md written: NO` — the malformed outer-loop table was
   never ingested, at plan time. (The `W1 (renders ...` token was sanitized
   per AC-1; only the three no-pattern prose fragments were refused.)
2. **Clean W1..W9 pass**: `exit_code=0`, `04-SKIN.md (9 SKIN behaviors)`,
   9 `| W<n> |` rows emitted — the reader-resolvable W-id count (so the
   run/journal/status denominator is 9, never the malformed world's 1).

## Mutation evidence (test strength)

Each mutation was applied, the new suites re-run, and reverted:

| Mutation | Expected kill | Actual |
| --- | --- | --- |
| **A** — validator neutered (`malformedIdReason` returns null unconditionally: everything is accepted, prose ids would be ingested) | refusal + no-artifact rows redden | **10 failed** / 18 passed → killed |
| **B** — emission neutered (`id = token` instead of `id = sanitized.id`: the raw contaminated token lands in the id column) | A-1405-1 emission rows redden | **2 failed** / 6 passed → killed |
| Restored tree | all green | **28/28 passed** |

## Gates (task protocol §5)

- Kernel cache hygiene: `rm -rf .dart_tool/test/`,
  `rm -f $TMPDIR/dart_test.kernel.*` pre- and post-test. Done.
- `dart analyze` on exactly the changed/new Dart files
  (`plan_command.dart`, `skin_plan_author.dart`, both new test files):
  **No issues found!** (repo-wide pre-existing infos untouched).
- `dart format .` then `dart format --set-exit-if-changed lib test` (the
  CI gate, ci.yaml line 151): **exit 0, 0 changed** — zero formatting
  diffs in lib/ + test/. (Formatting of `tool/` and `example/` files that
  `dart format .` flagged was reverted: pre-existing master drift, out of
  this PR's one-issue scope.)

## Success criteria: PROVED vs NOT

- SC-01 (strict emission, prose in behavior column): **PROVED** (unit
  U-1405-1/2 + CLI A-1405-1 + e2e check 2).
- SC-02 (no-pattern refusal, exit 2, no artifact): **PROVED** (CLI
  A-1405-2 ×3 + e2e check 1).
- SC-03 (malformation class named: spaces / unmatched paren / no pattern):
  **PROVED** (unit U-1405-4 precedence rows + validator refusal lines).
- SC-04 (clean W1-W9 → nine rows, reader resolves nine): **PROVED**
  (A-1405-3 — `TestListReader` + `LanePlanReader` resolution, the exact
  path gen/run and the journal status totals consume).
- SC-05 (canonical #1000 fixture byte-compatible): **PROVED** (A-1405-4 +
  U-1405-6 + the 59-test lane regression set, including the real example
  spec's `W1, A3..A7` SKIN routing form).
- SC-06 (rejection happens at plan time — no artifact exists after a
  refused plan): **PROVED** (file-absence assertions + e2e check 1).

Not proved / out of scope (honest flags):

- An end-to-end `zfa tdd status` 0/9 line was not driven: it requires the
  Flutter-side skin driver to produce lane receipts; the status command,
  run driver, gen, make and verify gate are outside this issue's fix
  scope by the hard constraints. The status denominator's INPUT (the
  machine-reachable W-id count the lane plan resolves) is proved at 9.
- `zfa tdd split`'s prior-list ingestion path is untouched (out of scope);
  its suite (`split_command_1000_test.dart`) passes unchanged.
- Unrelated pre-existing failures: none observed in any executed suite.
