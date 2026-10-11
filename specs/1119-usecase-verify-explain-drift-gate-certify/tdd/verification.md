# TDD verification — spec 1119 usecase verify / explain / drift gate / certify

## Test-first evidence

The behavior suites were written and run BEFORE implementation:

- `test/plugins/usecase/usecase_verify_test.dart` — RED: every behavior
  failed (`Could not find a subcommand "verify"` — the gate did not
  exist). 10 behaviors, 10 RED.
- `test/plugins/usecase/usecase_certify_test.dart` — RED: every behavior
  failed (`Could not find an option named "--certify"` /
  `"--explain"`). 7 behaviors, 7 RED.

GREEN after implementation: 17/17 pass (see Final evidence). The
regression perimeter (everything the refactor touched) is green too:
`test/plugins/usecase/` 59/59, `dead_positional_grammar` +
`manifest_flag_conformance` + `exit_code_sweep_1139` 34/34.

## Mutation-style evidence (the gate kills every mutant class)

Each mutant is a deliberate corruption of a generated artifact; the gate
must fail the run with a `--> fix:` line naming it.

| Mutant (applied by the suite) | Expected kill | Behaviors |
| --- | --- | --- |
| `Future<Product> execute` → `Future<String>` in `get_product_usecase.dart` | exit 1, `[signature_mismatch]` + fix line | B-002, B-005, B-021, B-022 |
| class `UpdateProductUseCase` renamed away (prescribed class missing) | exit 1, `missing_class` + fix line | B-003 |
| `get_product_usecase.dart` deleted from the tree | exit 1, `missing_file` + fix line | B-004 |
| entity source edited after create (hash divergence) | exit 1, `entity_drift` + fix line | B-010 |
| entity source deleted after create | exit 1, `entity_drift` + fix line | B-011 |
| receipts directory removed (no provenance) | gate still audits via discovery, `receiptBound: false` — never invents drift | B-007 |

## Shape-compatibility evidence (extend, never break)

- B-026 pins the create `--json` per-method verdict shape under
  `--certify --explain`: entries carry exactly `{name, action}` on a
  fresh create (the spec #972 shape) — the new keys live OUTSIDE the
  verdict entries (`explain`, `details.certification`, findings).
- B-025 pins the additive `explain` envelope key (issue #1122 pattern):
  base envelope keys unchanged.
- The pre-existing `usecase_create_json_test.dart` (4/4) and the full
  usecase plugin suite (59/59) pass unchanged against the refactored
  generator and command.

## Final evidence

```
dart test test/plugins/usecase/usecase_verify_test.dart \
          test/plugins/usecase/usecase_certify_test.dart
00:02 +17: All tests passed!

dart test test/plugins/usecase/
00:29 +59: All tests passed!

dart test test/commands/dead_positional_grammar_test.dart \
          test/commands/manifest_flag_conformance_test.dart \
          test/commands/exit_code_sweep_1139_test.dart
02:45 +34: All tests passed!

dart analyze <changed files>   → No issues found
dart format .                  → zero remaining formatting diffs
```

Success criteria proved: SC-1 (B-001..B-006), SC-2 (B-020..B-023),
SC-3 (B-024, B-025), SC-4 (B-007, B-010..B-012), SC-5 (B-026),
SC-6 (all suites green). Not proved here: analyzer-level compile of the
audited files (the gate audits signatures by AST, not the type checker)
— same trust tier as the service gate (spec #1127).
