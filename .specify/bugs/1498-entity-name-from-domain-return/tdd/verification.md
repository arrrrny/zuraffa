# TDD Verification: 1498-entity-name-from-domain-return

- **Date**: 2026-09-13
- **Branch**: fix/1498-entity-name-from-domain-return
- **Subjects**: `lib/src/plugins/tdd/services/routing_resolver.dart`,
  `lib/src/plugins/tdd/services/generation_planner.dart`
- **Test file**: `test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart`

## 1. Test-first evidence (red → green)

RED (recorded in tdd/red-evidence.md, against the unfixed tree):

```text
dart test test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart
00:00 +1 -8: Some tests failed.
```

8 of 9 behaviors failed for the RIGHT reason (entityName null, plan
fell through to the func lane, no surface provenance, RoutingDecision
instead of refusal, refusal plan expressible). U-1498i is the
regression guard pinning preserved behavior (declared scalar → func
lane) and was green from the start by design.

GREEN (same file, after the fix):

```text
dart test test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart
00:00 +9: All tests passed!
```

## 2. Regression evidence (chunked suite — no new failures)

The full-suite single run is unreliable on this host (the dart_test
kernel cache grows to multi-GB, fills the disk mid-run and poisons the
tail with LOADING failures — the same class tracked by bug #1096
cross-suite races; a pristine-baseline single run showed the same
~121 loading failures, all `Failed to load ... No space left on
device`). Verification therefore used the chunked protocol with cache
cleanup between chunks (scripts/run_chunked.sh, 12 files per chunk):

- Full tree, chunked: 333 `*_test.dart` files / 29 chunks — every
  chunk `All tests passed` (three chunks initially listed helper
  `*.dart` non-test files in the runner invocation, producing
  load-failures for those HELPER files only; re-run with the corrected
  test-only lists: `+171: All tests passed`).
- Directly affected files re-run individually after `dart format`
  (34 tests green):
  routing_resolver_test, generation_planner_declared_test,
  bug_1498_entity_name_from_domain_return_test.
- Suspect-from-disk-pressure file re-run in isolation:
  test/plugins/tdd/services/pipeline_runner_test.dart →
  `+16: All tests passed`.
- Domain/data-row and entityPipeline-adjacent suites confirmed green:
  plan_traces_cell_1310, bug_1259_vacuous_green,
  bug_1500_wire_contract_subject, plan_unbound_traces_1319,
  bug_1320_declared_assertion_reachable, contract_kind_1007,
  plan_skin_contract_1004, contract_blocked_e2e_1007,
  bug_1141_ledger_wiring, spec_1142_adaptive_layout,
  bug_965_i18n_key_contracts, spec_parser_contract_files_1485,
  spec_parser_hardening_1196, function_contracts_parsing,
  bug_919_template_structures, ingest_command, dream_command,
  bug_1503_mock_create_certify_pipeline.

## 3. Static analysis

```text
dart analyze lib/src/plugins/tdd/services/routing_resolver.dart \
             lib/src/plugins/tdd/services/generation_planner.dart \
             test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart
No issues found!
```

(`dart analyze` on the changed files: no new warnings. The repo-wide
analyzer/format state is untouched outside the three files above — the
repo carries pre-existing format drift in 75 unrelated files, so
formatting was applied to the changed files only.)

## 4. Test-smell rubric

- **Behavior-named**: every test id names the observable behavior
  (derivation, plan, provenance, refusal, preserved lane), not the
  implementation unit.
- **One reason per red**: each RED test failed on exactly the #1498
  gap it pins (see red-evidence.md table) — no shotgun assertions.
- **Guard discipline**: U-1498i pins the PRESERVED lane (declared
  scalar → func) so the fix cannot overreach; U-1498g pins the
  refusal's message contract (`dropped: no entity name`, `--> fix:`).
- **No vacuous greens**: U-1498b asserts the full 4-step engine AND
  the absence of a `tdd func` step; U-1498h asserts the refusal has NO
  steps.
- **Pure subjects**: both subjects are pure by contract; no fixtures,
  no subprocesses, no I/O in the new tests.

## 5. Acceptance-criteria coverage

| #1498 expected item | Covered by |
| ------------------- | ---------- |
| 1. Mine the domain row's return type (unwrap Future/List/Set/Iterable) | U-1498a, U-1498d, U-1498e |
| 2. Refuse when underivable (RoutingFailure / honest refusal plan, never `return null` into legacy) | U-1498g (resolver), U-1498h (plan builder) |
| 3. Surface in routing provenance (`surface: entityPipeline`; `dropped: no entity name` in failure) | U-1498c, U-1498g, U-1498h |
| 4. `_tracedEntityFor` prose regex | Deferred by design (see fix.md scope notes): the declared ladder now resolves the entity before the prose fallback engages; replacing the regex wholesale would regress the #829 labeled-fallback contract its tests pin |
| 5. Plan-time lane report | Deferred (requires a make/plan-command tally outside the hard-constrained two-file fix surface); per-route provenance delivers the same information per behavior |
| Hard: fix confined to routing_resolver.dart + generation_planner.dart | git diff --stat: exactly those two files (+ test, + artifacts) |
| Hard: derive from the row's OWN return type, not prose, not Key-Entities-only | U-1498a/d (no prose anywhere in the fixtures; U-1498d's registry-less corroboration path covered by the U7-1259 shape) |
| Hard: refuse when entityPipeline computed but entityName underivable | U-1498g, U-1498h |
| Hard: dart analyze, no new warnings | Section 3 |

## 6. Mutation spot-check (honesty probe)

The miner's guard set and unwrap loop are exercised from both sides by
U-1498d (positive forms) and U-1498i / U-1498h (negative forms: scalar
and non-unwrappable containers). Reverting the mining block restores
the RED state for U-1498a…h (the recorded red), so the suite cannot
pass with the fix stubbed out.
