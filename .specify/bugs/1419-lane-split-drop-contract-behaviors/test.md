# Test: lane-split plan includes derived Layer Contract behaviors (#1419)

- **Slug**: 1419-lane-split-drop-contract-behaviors
- **Suite**: `test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart`
- **Method**: in-process CLI (`CliRunner.runCapturing(['tdd', 'plan',
  '--project', <tmp>, '004-login-ui'])`) over temp fixtures, the same
  harness the sibling #1432 suite uses.

## Fixtures

| Fixture | Shape |
| ------- | ----- |
| `contractLanesSpec` | Layer Contracts (MessageTransport: send/acknowledge) + CORE lane declaring only A1/A2/U1/U2 — the issue's repro shape |
| `declaredCoreContractSpec` | the same + `contract:A1, contract:A2` declared in the CORE lane |
| `declaredSkinContractSpec` | `contract:A1` declared into the SKIN lane |
| `flutterReferenceContractSpec` | contract signature text referencing `package:flutter` |
| `contractNoLanesSpec` | Layer Contracts with NO `## Lanes` — the #1309 stale-split regeneration shape |
| `priorBlockedList` | legacy single-file list with a BLOCKED `contract:A1` row |
| `legacyListWithContract` | legacy single-file list (`zfa tdd split` migration) carrying a BLOCKED `contract:A1` row |

## Behaviors

| id | assertion |
| -- | --------- |
| A-1419-1 | plan exits 0 and `04-ENGINE.md` carries the contract-loop section with the derived rows: `| contract:A1 | MessageTransport.send(OutboundMessage) -> Message (entity method contract) | MessageTransport.send | PENDING |` (and A2) |
| A-1419-2 | `TestListReader` resolves `contract:A1`/`contract:A2` from the split artifacts with `kind == BehaviorKind.contract` |
| A-1419-3 | the meta-index's CORE row resolves the contract ids AND its declared id set equals the engine artifact's row set (the extraction is scoped to the behavior sections, so declaration-table headers cannot enter the id set) |
| A-1419-4 | a CORE declaration joins the derived behavior: derived description + `MessageTransport.send` trace + contract kind; no `core behavior declared in ## Lanes` clobber row, no `\| LANE:CORE \|` trace |
| A-1419-5 | a SKIN-declared contract id refuses (exit 2) naming `contract:A1`; no lane artifacts written |
| A-1419-6 | a recorded BLOCKED contract state re-plans BLOCKED into the engine plan (spec-1007 BLOCKED semantics survive the split) |
| A-1419-7 | a contract signature referencing `package:flutter` refuses via the noFlutter guard (the engine lane is pure Dart by construction) |
| A-1419-8 | a receipt-bearing feature with NO `## Lanes` regenerates the contract rows into `04-ENGINE.md` through the `_heuristicLaneResolution` path, and the regenerated meta-index counts `contract:A1` in CORE |
| A-1419-9 | `zfa tdd split`'s legacy-list migration keeps its `contract:A1` row in `04-ENGINE.md` — the section is written by the renderer both commands call, not at the `plan` call site |

## RED phase (recorded against the unfixed tree, this session)

`dart test test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart`
→ `00:00 +0 -6: Some tests failed.` — all six originals failed for the
right reasons: the captured plan output shows the route log claiming
`route: contract:A1 -> contract lane [declared: MessageTransport]`
while the engine plan carries only the A/U rows (A-1419-1/2/3/6), the
declared id renders the anonymous hand row (A-1419-4), and the SKIN
declaration exits 0 (A-1419-5). A-1419-7 was added with the guard it
pins (pre-fix the row was silently dropped, exit 0 — the refusal was
equally absent).

## GREEN phase (this session)

`dart test test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart`
→ `00:00 +7: All tests passed!`

## Review round (follow-up commit, this session)

A-1419-8 and A-1419-9 were added for the review findings: the #1309
heuristic regeneration branch (previously asserted only by reading) and
the `zfa tdd split` migration path (which the review PROVED still
dropped the contract rows while its meta-index and receipt classified
them). A-1419-9 is red against the previous commit for exactly that
reason:

```
$ dart test ...bug_1419_lane_split_contract_rows_test.dart --name A-1419-9
  (lib/ reverted to the previous commit)
→ 00:00 +0 -1: Some tests failed.
  Expected: contains '| contract:A1 | MessageTransport.send(OutboundMessage) -> Message (entity method contract) | MessageTransport.send | BLOCKED |'
    Actual: '# Engine Plan: 004-login-ui (CORE + BOTH)\n'
```

```
$ dart test test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart
→ 00:01 +9: All tests passed!
```
