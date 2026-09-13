# TDD Verification — 1541-contract-harness-declared-shape-args

**Verified**: 2026-09-13 · **Branch**: `feat/1541-contract-harness-declared-shape-args`

## Red → Green evidence

| behavior | red evidence (pre-fix) | green evidence (post-fix) |
| -- | -- | -- |
| U-1541-1 | render carries `impl(null)` for a `dynamic` param; no `_arg0()` seam, no `provide a representative` instruction (2 RED pins) | 10/10 `bug_1541_contract_harness_args_test.dart`; e2e: scaffold passes `_arg0()`, `type 'Null' is not a subtype` UNREACHABLE, representative value satisfies the validating seam |
| U-1541-2 | emitted `_captured` catches only `on UnimplementedError` (2 RED pins) | catch-all `on Object catch (error)` emitted for every parseable render; the #1541 outcome split documented in the helper doc |
| U-1541-3 | Case 3's `isA<...>` assertion unguarded (1 RED pin) | guard `if (_rejection == null)` on the capture SIGNAL emitted (PR #1558 review — replaces the runtime-type guess `outcome is! Error && outcome is! Exception`); a thrown raw value fails the guard's Error/Exception assertion instead of passing as a return; the #1007 pins (`Case 1 of 3` / `Case 2 of 3` / `Case 3 of 3`, `isNot(isA<UnimplementedError>())`, one test) unchanged; nullable complex type keeps `impl(null)` |
| U-1541-4 | (new e2e — the pre-fix classification for this scenario is `runner-error`: the uncaught `ArgumentError` carries no assertion signature) | real `dart test` run PASSES (exit 0) on the validating seam; verify-red grades `classification=unexpected-green` |
| U-1541-5 | — (regression guard) | unimplemented seam STILL grades `classification=blocked certified=false` + `contract-blocked.A1.json` receipt |
| U-1541-6 | the #1513 golden byte-compare fails against the new render (documented drift) | fixture REGENERATED from the updated writer (same fixture shape); B8 byte-compare passes; `impl(0, 0)` scalar arguments survive |
| U-1541-7 | baseline `dart analyze` = 112 pre-existing issues | `dart analyze lib test bin` = 112 issues, the issue SET byte-identical to baseline (0 new) |
| U-1541-8 | review finding: pre-fix `impl(_arg0())` for `List<String>` — the pair fails to LOAD (`Object?` can't be assigned to `List<String>`) | literal renders (`<T>[]`, `<T>{}`, `<K, V>{}`, `const Stream.empty()`, `Future<T>.value(...)`; `List<dynamic>` settles its inner; `Future<dynamic>` nests the inner-typed placeholder; non-renderable inners keep the placeholder); e2e: the real `dart test` pair loads, blocks at the Case 2 assertion (`Expected:` present, no load/compile error), and satisfies with an implementation (slow tier) |
| U-1541-9 | review finding: `String label(String name) => throw 'not implemented yet'` PASSED the contract test (exit 0 — no return value ever produced) | `_captured` records `_rejection` (reset per capture); the Case 3 guard reads the signal; the raw-throw e2e fails with the named `threw a raw value` assertion; a returned value still type-checks; two-case renders emit no rejection signal |

## Changed-file test matrix

| file | tests |
| -- | -- |
| `lib/src/plugins/tdd/services/contract_test_writer.dart` | `test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart` (18), `test/plugins/tdd/commands/contract_satisfied_with_rejection_e2e_1541_test.dart` (5, slow), `bug_1513_contract_lane_flutter_imports_test.dart` (10), `contract_kind_1007_test.dart` (21), `bug_1443_void_contract_seam_test.dart`, `bug_1363_contract_stub_dup_args_test.dart`, `test/tdd/004-login-ui/contract_a1_test.dart` |
| `test/fixtures/baseline_outputs/bug_1513_contract_default_render.txt` | the #1513 B8 byte-comparison (regenerated, green) |

## Verification commands (as run)

```bash
# red (pre-fix)
dart test test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart          # 5 red / 5 green
# review-fix pins against the pre-fix writer (PR #1558 findings)
# → 10 pass / 8 red (U-1541-3 signal pin; 5 of 6 U-1541-8 shape pins; both U-1541-9 pins)

# green (post-fix)
dart test test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart          # 18/18
dart test --preset=all test/plugins/tdd/commands/contract_satisfied_with_rejection_e2e_1541_test.dart  # 5/5 (slow tier)
dart test test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart test/plugins/tdd/commands/contract_kind_1007_test.dart test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart test/plugins/tdd/services/bug_1443_void_contract_seam_test.dart test/tdd/004-login-ui/contract_a1_test.dart  # 50/50 combined
dart test test/plugins/tdd/commands   # 532 pass + the pre-existing macOS view_command U-V3 failure (issue #1463; identical on the base with the changes stashed)
dart test test/plugins/tdd/services   # 952 pass + 1 skip
dart test test/tdd                    # 157 pass
dart test test/plugins/mock           # 157 pass
dart test test/commands               # 370 pass

# analyzer parity
dart analyze lib test bin             # 112 issues — identical set to the pre-change baseline
dart format lib/src/plugins/tdd/services/contract_test_writer.dart test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart test/plugins/tdd/commands/contract_satisfied_with_rejection_e2e_1541_test.dart
```

## Scope audit (FR-005)

- `git diff --name-only` vs master touches: the writer, the regenerated
  fixture, the two NEW test files, and the spec artifacts. The verify-red
  classifier, the blocked verdict, the contract-blocked receipt, the run
  driver's state machine, the seam writer, the unit/acceptance lanes, and
  the golden harness writer are untouched.

## Notes

- Slow-tier runs used the chunked convention (`dart_test.yaml` warns the
  whole-tree fast run can blow the kernel cache on ~10 GB disks — an
  earlier un-chunked run produced 244 `Failed to load` infrastructure
  errors that the chunked runs clear; no behavioral failure existed).
- The regeneration was mechanical (writer output for the exact B8 fixture
  shape); the scratch runner script was kept OUT of the repo.
- **Review-fix follow-up (PR #1558 findings)**: the writer now emits
  representative literals for declared types the seam renders verbatim
  (the `Object?` placeholder could not compile against them — the pair
  failed to LOAD) and replaces the Case 3 runtime-type guess with the
  `_rejection` capture signal (a raw-throwing seam was graded as a
  return). The golden fixture was regenerated again from the updated
  writer, the #1541 fast suite grew to 18 pins (8 red against the
  pre-fix writer), and the slow e2e grew to 5 cases (the `List<String>`
  load/satisfy path and the raw-throw surface). Wider fast-tier chunk
  re-runs and the analyzer parity check are recorded above; the emitted
  two-case scaffolds stay analyzer-clean (no unread `_rejection`).
