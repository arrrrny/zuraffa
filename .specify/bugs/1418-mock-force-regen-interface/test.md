# Bug Verification: `zfa mock create --force` regenerates the pair; hide names verified

- **Slug**: 1418-mock-force-regen-interface
- **Tested**: 2026-09-16
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: PASS — red → green → verify, fresh from real runs; see `specs/1418-mock-force-regen-interface/tdd/verification.md`

## Summary

The reported symptom is gone. The issue's exact two-command sequence —
`zfa mock create Deal --methods list` then
`zfa mock create Deal --methods getList --certify --force` — now ends in
`✅ mock certification: Deal conforms to DealDataSource (mock-cert:deal@cd05085d)`
with the interface regenerated to `getList(ListQueryParams<Deal> params)`
(it previously dead-ended on `Missing concrete implementation of
'DealDataSource.list'` with a `DRIFT` receipt on every `--force` re-run).
Generated datasource files emit no unverified hide names, so
`undefined_hidden_name` can no longer fail `zfa build`'s analyze gate from
generator-owned output. The non-force, append and revert contracts are
byte-preserved (T2/T3/T4), and the #942/#1530/#1570/#417 regression pins
stay green.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Live repro (pre-fix, master 0c50b959) | `bash scripts/repro_1418.sh` (sandbox project, path-dep on the repo checkout) | fail as designed | Step 2 left the interface at `list(NoParams)` while the mock implemented `getList`; `❌ mock certification for Deal failed — unsatisfied: list` (receipt DRIFT). Recorded in the fetch/fix phase and re-observed in-cycle. |
| RED (pre-fix, lib stashed) | `dart test test/plugins/mock/mock_builder_1418_force_interface_test.dart` | fail as designed | `+3 -2`: T1 and T5 fail on the stale interface (`Expected: contains 'getList(ListQueryParams<Deal>'` / interface still declares `list(NoParams)`); T2/T3/T4 pass — the contracts the fix must preserve. |
| RED (pre-fix, lib stashed) | `dart test test/plugins/mock/mock_builder_1418_force_compile_test.dart` | fail as designed | `+0 -1` in `setUpAll`: after `--methods getList --force` the interface still declares `list(NoParams)`. |
| RED (pre-fix, lib stashed) | `dart test test/utils/zuraffa_barrel_exports_mock_surface_test.dart` | fail as designed | Load error: `Member not found: 'EntityUtils.mockBarrelHideNames'` (the fix API does not exist on master). |
| GREEN (post-fix) | same three files + `dart test test/plugins/mock/ test/utils/zuraffa_barrel_exports_test.dart test/utils/zuraffa_barrel_exports_mock_surface_test.dart test/plugins/datasource/barrel_hide_unverified_1530_test.dart test/regression/issue_942_entity_name_collides_framework_export_test.dart test/regression/issue_417_mock_datasource_missing_interface_test.dart` | pass | Full scoped sweep `+229 -0` (entire mock lane, barrel-surface utils, datasource lane pins, #942/#417 regressions) and `+37 -0` on the focused 1418 file set. |
| Datasource lane (other hide consumer) | `dart test test/plugins/datasource/` | pass | `+73 -0` — `barrelHideNames` consumers unaffected. |
| Live repro (post-fix, E2E with certification) | `bash scripts/repro_1418.sh` | pass | Interface after step 2 declares `getList(ListQueryParams<Deal>)`; `✅ mock certification: Deal conforms to DealDataSource (mock-cert:deal@cd05085d)`; no `hide` combinators emitted for a non-exported entity. |
| Mutation analog A (guard reverted) | remove `\|\| forceRegeneratesInterface` from the mock_builder guard, re-run the interface suite | killed | `+3 -2`: T1 + T5 fail again while T2/T3/T4 stay green — the suite discriminates the regression, not just the feature. |
| Mutation analog B (wrong surface) | `filterMock` delegating to `filter`, re-run the surface suite | killed | T7/T8/T10 fail — the emission-level and resolution-level tests both catch the unverified hide. |
| Analyzer | `dart analyze` over the five changed lib files + three test files | pass | `No issues found!` |
| Formatting | `dart format` on all changed files, then `dart format --output=none --set-exit-if-changed lib/ test/plugins/mock/ …` | pass | Second pass: 1299 files, 0 changed (format-stable); suites re-run green after formatting. |
| Deterministic engine gate | `dart run bin/zfa.dart tdd verify --feature 1418-mock-force-regen-interface` | not_assessed (honest) | `no behavior artifacts registered` — the zfa-native mutation gate needs feature-workflow behavior artifacts, which the bug workflow does not produce; the fallback LLM-guided audit (this file + tdd/verification.md) applies per the tdd.verify command. |

## Residual Risks

- The mock-barrel resolution walks `lib/mock.dart`'s export chain with the
  same depth cap (3) and combinator semantics as the core barrel walker; a
  mock barrel that re-exports an EXTERNAL package (`package:other/…`) is
  skipped by the existing external-re-export rule — under-collection, the
  safe direction (no hide emitted, never an unverified hide).
- `src/mock/mock.dart` currently bare-re-exports the full core surface, so
  today's generated output is byte-identical to the pre-fix behavior for
  every entity the core barrel exports; the change only matters when the
  barrel layout diverges (exactly the #1418 warning class).
- `appendToExisting` interface appends remain a datasource-lane concern;
  the mock lane still never appends to an interface (unchanged from #417).
