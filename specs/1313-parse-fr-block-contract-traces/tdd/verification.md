feature: specs/1313-parse-fr-block-contract-traces (issue #1319, branch feat/1319-parseFrContractTraces-multiline-fr-block)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree @ feat/1319-parseFrContractTraces-multiline-fr-block
behaviors: 8 (4 acceptance + 4 unit spec rows; 18 suite tests covering them)
proven: 4
likely: 0
test_after: 0
no_test: 0
high_smells: 0
mutation_score: 5/5 killed # scope: spec_parser.dart (parseFrContractTraces block scan reverted to lines[i+1]; heading boundary disabled; findUnboundFrTraces neutered) + plan_command.dart (loud warning print disabled; declared-row provenance reverted to the anonymous label) — deliberate manual mutants, each applied to the working tree, each killed by a named test in spec_parser_traces_1319_test.dart / plan_unbound_traces_1319_test.dart / contract_kind_1007_test.dart, then reverted (restoration verified by dart analyze + suite re-run)
mutants_survived: 0
equivalent_mutants: 1 # first M4 attempt (stdout warning print disabled) survived the non-strict harness because the provenance record re-prints the same WARNING line later; replaced by the strict-refusal mutant context — the warning must print BEFORE the gate mutes the provenance output, which the new test pins (the strict-refusal test asserts the warning with exit 1 and no artifacts)
suite: "spec_parser_traces_1319_test.dart 13/13; plan_unbound_traces_1319_test.dart 5/5; neighbors all green post-format: contract_kind_1007_test.dart, spec_parser_declarations_test.dart, spec_parser_hardening_1196_test.dart, routing_resolver_test.dart, plan_routing_provenance_test.dart (97/97 combined) + full plugin scope (test/plugins/tdd/services/ 772/772, test/plugins/tdd/commands/ 391/391); dart analyze: no issues in the five touched files; dart format: `dart format --set-exit-if-changed` on the touched files exit 0 (0 diffs)"

---

# TDD Verification: issue #1319 — parseFrContractTraces scans the full FR block

**Verdict: PASS.** The red→green cycle is real: the RED phase ran the new
suites against the unmodified tree (compile-red on the missing
`findUnboundFrTraces` API; assertion-red `00:00 +1 -3` for the plan
harness — the repro binding, the loud WARNING and the declared-row
provenance all absent — and `+0 -1` for the updated #1007 provenance
assertion), the GREEN phase was driven by the two touched production
files only, and five deliberate mutants were each killed by a named
test. The hard constraints hold: the core engine cycle, the test-list
generation (`_render`), the gen/make pipeline, the verify gate, the FR
body-text scanner (`_extractUnit`) and `parsePersistenceDeclarations`
are untouched (`git diff --stat`: `spec_parser.dart` +88/-6,
`plan_command.dart` +30/-4, the updated #1007 assertion, two new test
files, the spec artifacts — nothing else).

## RED evidence (unmodified tree)

```
dart test test/plugins/tdd/services/spec_parser_traces_1319_test.dart
  Error: Member not found: 'SpecParser.findUnboundFrTraces'.   (compile-red)

dart test test/plugins/tdd/commands/plan_unbound_traces_1319_test.dart
00:00 +1 -3: Some tests failed.                                (assertion-red)

dart test test/plugins/tdd/commands/contract_kind_1007_test.dart  (updated assertion)
00:00 +0 -1: Some tests failed.
```

The 3 plan-harness failures are exactly the new behaviors: the wrapped
FR's trace does not bind (`[fallback: legacy description classifier
matched — trace FR to a declared contract row]` printed against the
declared `RouteContentType` row — the live #1319 symptom), no
`WARNING: traces: line found in FR-001 ...` line anywhere, and the
contract provenance carrying the anonymous
`[declared: layer contracts section]` label. The +1 is the
backward-compat guard (a bound trace emits no WARNING) — green before
and after, as required.

## GREEN evidence

```
dart test test/plugins/tdd/services/spec_parser_traces_1319_test.dart
00:00 +13: All tests passed!

dart test test/plugins/tdd/commands/plan_unbound_traces_1319_test.dart
00:00 +5: All tests passed!

dart test test/plugins/tdd/services/  →  01:20 +772: All tests passed!
dart test test/plugins/tdd/commands/  →  01:20 +391: All tests passed!
```

## Mutation evidence (manual mutants, each killed then reverted)

| # | Mutant | Killed by |
|---|--------|-----------|
| M1 | block scan reverted to the single line after the FR header (`j <= i + 1`) | 5 failures: the repro binding, the FR-boundary, table-variant, multi-FR and plan-repro tests (`spec_parser_traces_1319_test.dart` A-group; `plan_unbound_traces_1319_test.dart` A) |
| M2 | `_endsFrBlock` heading boundary disabled | "a traces: line after a markdown heading binds to nothing" fails |
| M3 | `findUnboundFrTraces` returns const {} | the empty-token unbound unit test + the plan WARNING test fail (+15 -2) |
| M4 | plan's immediate loud WARNING print disabled | the strict-refusal test fails: exit 1, no artifacts, no provenance print-out — and the warning must still have fired (+4 -1); the first attempt (non-strict harness only) was equivalent because the provenance record re-prints the warning — replaced by the stricter contract |
| M5 | contract provenance reverted to `[declared: layer contracts section]` | the C-group provenance test AND the updated contract_kind_1007 assertion fail (+0 -1 / +12 -1) |

Score: 5/5 killed, 0 survived, 1 equivalent discarded by construction.

## Live CLI demo (real transcript, from the PR body)

```
$ # the #1319 repro spec: FR-001 wraps, traces: RouteContentType sits after the wrap
$ dart run bin/zfa.dart tdd plan conversation_streaming --project <tmp>

BEFORE (unmodified tree):
   route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
   route: contract:A1 -> contract lane [declared: layer contracts section]

AFTER (this fix):
   route: U1 -> unit lane [declared: contract row: RouteContentType, spec line 8]
   route: contract:A1 -> contract lane [declared: RouteContentType]

$ # an unbindable traces: line (lone inline signature) can no longer fall back silently:
$ dart run bin/zfa.dart tdd plan warn_demo --project <tmp>
zfa tdd plan: WARNING: traces: line found in FR-001 but was not bound to a contract row — check indentation
   route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
   WARNING: traces: line found in FR-001 but was not bound to a contract row — check indentation
```

The single-line FR grammar is byte-compatible: every pre-existing trace
test (`spec_parser_declarations_test.dart`,
`spec_parser_hardening_1196_test.dart` table-FR traces,
`routing_resolver_test.dart` backticked-signature drop,
`plan_routing_provenance_test.dart` `[declared: contract row: Formatter`)
passes unmodified.
