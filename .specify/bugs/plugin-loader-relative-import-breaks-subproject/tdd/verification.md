---
feature: plugin-loader-relative-import-breaks-subproject
issue: 1269
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: a873178b
behaviors: 2
proven: 2
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: 1/1 # deliberate mutant (original bug replayed) caught by the red run
mutants_survived: 0
suite: targeted tiers only (cloud disk constraint; full suite not run): test/cli/plugin_loader_test.dart 3 passed / 0 failed; test/cli/ + dependent chunks (test/core/plugin_system, test/core/feature_scoped_loading_test, test/core/planning, test/agent/plugin/config_precedence_test, test/plugins/slice/slice_plugin_registration_test, test/commands/observer_removed_test) 277 passed / 0 failed; dependent-chunk re-run 75 passed / 0 failed; dart analyze on changed files clean; dart format on touched files clean
---

# TDD Verification: plugin_loader.dart relative import breaks subproject runs (#1269)

**Verdict: PASS.** `lib/src/cli/plugin_loader.dart` now imports the
`FeatureContract` entity through an absolute package import
(`package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart`)
instead of the relative `../domain/entities/feature_contract/feature_contract.dart`.
Two regression tests pin the contract: every `feature_contract` import in
`plugin_loader.dart` must be an absolute `package:zuraffa/` import, and the
imported path must resolve to a real package file that declares the
`FeatureContract` type. Both tests were committed RED before the fix
(commit `a873178b`, git ordering proves test-first) and are green after it.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — `plugin_loader.dart` references `feature_contract` only via absolute `package:zuraffa/` imports | PROVEN | Commit `a873178b` lands the pin tests alone; red run against pre-fix lib produced `Expected: contains 'import 'package:zuraffa/' / Actual: 'import '../domain/entities/feature_contract/feature_contract.dart';'` (1 passed, 2 failed — both failures name the exact defect). Fix commit follows; green: 3/3 |
| B2 — the absolute import path resolves to a real package file declaring `FeatureContract` | PROVEN | Red run failed with `Import must be an absolute package import` (no package import existed); after the fix the test extracts the package path, maps it to `lib/src/domain/entities/feature_contract/feature_contract.dart`, asserts the file exists and declares the type (`abstract class $FeatureContract` base + zorphy part `class FeatureContract`). This kills the wrong-path mutant (e.g. the literal `package:zuraffa/domain/...` spelling suggested in the remediation notes does NOT exist in this tree — `lib/domain/` is absent and the barrel does not export the entity; the only resolving absolute path is the `src/` one used) |

## Findings

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | LOW | The pin tests read `lib/src/cli/plugin_loader.dart` relative to the package root (valid under `dart test`, which runs from the package root). They are source-contract tests, not compile-behavior tests: a future refactor that moves the loader must update `_pluginLoaderSourcePath` | `test/cli/plugin_loader_test.dart` |
| 2 | LOW | Generated entity files (`feature_contract.zorphy.dart`, `feature_id.dart`, `xray_layer.dart`) were verified present in HEAD; no regeneration was required, so the "regenerate if deleted" arm of the remediation was a no-op | `lib/src/domain/entities/feature_contract/` listing at `a873178b` |
| 3 | INFO | Bug records `.specify/bugs/plugin-loader-relative-import-breaks-subproject/{issue,assessment}.md` were absent from the clone; the fix followed the task brief's root-cause/remediation section, verified against actual source state (line 8 relative import confirmed before the fix) | this file, PR body |
| 4 | INFO | Pre-existing format drift exists in 3 files under `specs/1142-adaptive-layout-contract/tdd/evidence/` (unformatted in HEAD, untouched by this PR per the one-bug-per-PR constraint). `dart format .` flags them; they are NOT part of this change | `git status` at `a873178b` |

## Mutation results

No mutation tool in the profile; deliberate mutant on the only behavior the
fix depends on.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| Re-introduce the relative import (the original bug, replayed) | B1 (and B2) | No | Red run: both pin tests failed naming the relative import; restored absolute import, suite green |

1 mutant sampled, 1 caught.

## Subproject compilation proof

Consumer subproject (`path:` dependency on zuraffa) ran, from its own working
directory: `dart run bin/main.dart` (compiles the app against the zuraffa
public surface) and `dart run zuraffa:zfa plugin list` (compiles and executes
`PluginLoader` through the fixed import) — both succeeded post-fix
(`[✓] repository - Repository Plugin (1.0.0)` … full registry listed). With a
path dependency the pre-fix relative import still compiles in this sandbox
(relative URIs resolve inside the package checkout), so the deterministic
source-contract pin is the regression guard; the subproject run proves the
fixed package compiles and drives the plugin registry from a consumer CWD.

## Acceptance criteria (from the remediation contract)

| Criterion | Status |
| --------- | ------ |
| Replace the relative import with an absolute package import | PROVED — 1-line diff on `lib/src/cli/plugin_loader.dart` line 8 |
| Verify the exported path exists (`lib/zuraffa.dart` barrel check) | PROVED — barrel does not export the entity; import uses the direct `src/` path that exists and compiles (analyzer + tests green); B2 pins the target file |
| Regenerate missing generated files if needed | N/A — all generated files present in HEAD (finding #2) |
| No package restructuring / no file moves | PROVED — `git diff --stat` = 2 files (fix + tests), 0 moves |
| Suite: no new failures | PROVED — 277/277 and 75/75 on all chunks exercising the loader; 0 failures |
