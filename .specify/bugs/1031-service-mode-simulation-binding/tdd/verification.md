---
feature: 1031-service-mode-simulation-binding
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 77e69f24
behaviors: 3
proven: 2
likely: 1
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # no mutation tool; deliberate mutant 1/1 caught
mutants_survived: 0
suite: fast tier chunked 74/74 chunks passed / 0 failed; CI-scope dart analyze exit 0 (294 info / 20 warning / 0 errors, identical to baseline)
---

# TDD Verification: service-mode simulation binding emits service shape not datasource (#1031)

**Verdict: PASS_WITH_GAPS.** The service-mode mock lane now emits the
service-shaped simulation binding (`<Name>Service` -> `<Name>MockProvider`
behind the single `kSimulationMode` flavor switch) and never the
datasource shape, pinned by B1 (exact file name, function signature,
interface-typed registration, both resolving imports, absence of the
datasource-shaped file), B2 (index discovers the service-shaped function
through the same RegistrationDetector contract) and B3 (datasource-lane
invariance). The deliberate mutant — replaying the original bug by
reverting the lib fix while keeping the new tests — was caught by B1+B2.
Gap: test-first evidence is `LIKELY` for the same commit the repo's #609
verification records — red ran before the fix in-session (CLI repro with
four binding errors + `+8 -2` unit run), but test and fix land in one
commit so git ordering cannot independently prove it.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — service mode emits the service shape, never the datasource shape | LIKELY | cycle-log Cycle 1 red block: scratch-project CLI repro emitted `auth_simulation_datasource_di.dart` and `dart analyze` failed with the four binding errors (`uri_does_not_exist` x2, `non_type_as_type_argument`, `undefined_function`); unit run `+8 -2` before the fix, `+10` after; saved in `../red-evidence.md`. Same-commit caveat as the #609 precedent |
| B2 — index registers the service-shaped binding | LIKELY | red: `Which: does not contain 'registerAuthSimulationService(getIt);'` (pre-fix index only knew the datasource function); green after fix. Same-commit caveat |
| B3 — datasource lane unchanged | PROVEN | pre-existing spec-893 tests (A2/A3/U3/U4/U6, mock-builder simulation entries) were green at base `77e69f24` and stayed green through every run; the new B3 pin adds the negative assertion (entity mode never emits the service shape) |

No pre-existing test was weakened or deleted: the fix only adds a branch
at the mock plugin call site and new builder methods; every existing
assertion survived unchanged (74/74 fast-tier chunks, 0 failures).

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | LOW | Pre-fix debris: a binding file already emitted by a pre-fix run (`<name>_simulation_datasource_di.dart`) is not purged by the fix; the index regeneration will still import it. The issue's sandbox already worked around this by deleting the file; a re-run of `zfa mock create --service` in a clean tree never produces it | issue.md Context; `SimulationBindingEmitter.regenerateIndex` scans whatever `_di.dart` files exist |
| 2 | LOW | The service import resolution checks the domain-scoped path on disk, falling back to the domain-less layout — a project holding BOTH layouts for the same service resolves to the domain-scoped import. Matches `DiPlugin._generateServiceDI`'s existing precedence, so both lanes agree | mock_plugin.dart call site comment |
| 3 | LOW | B1 is refactoring-sensitive by design (file name, function name and import paths are the generated contract under test); a future shape change should intentionally break it | test/plugins/di/simulation_binding_test.dart |

## Mutation results

No mutation tool in the profile; deliberate mutant on the behavior the
whole fix depends on (the `config.hasService` branch — the original bug,
replayed).

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| revert the two lib changes (branch on hasService removed → datasource shape emitted in service mode), tests kept | B1 (and B2) | No | B1+B2 failed (`+8 -2`); restored, suite green (`+10: All tests passed!`) |

1 mutant sampled, 1 caught. B3 shares no mutation surface with the
mutant (datasource lane untouched by it) — its guard is the untouched
spec-893 suite.

## Acceptance-criteria coverage

| Issue criterion | Covered by |
| --------------- | ---------- |
| Service mode emits `<Name>Service` -> `<Name>MockProvider` binding (exact expected body) | B1 (pinned verbatim: function name, flavor guard, typed registration, constructor call) |
| Datasource-shaped binding not emitted in service mode | B1 negative assertion |
| Imports resolve to the generated service interface + mock provider | B1 import pins; CLI repro analyze clean under `di/simulation/` |
| Datasource lane unchanged | B3 + untouched spec-893 suite |
| Index keeps registering bindings (FR-002 continuity) | B2 |
