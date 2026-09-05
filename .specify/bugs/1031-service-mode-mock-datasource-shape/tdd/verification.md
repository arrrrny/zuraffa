# TDD Verification — Bug #1031 (service-mode mock emits datasource-shaped simulation binding)

- Feature slug: `1031-service-mode-mock-datasource-shape`
- Branch: `fix/1031-service-mode-mock-datasource-shape`
- Date: 2026-09-05
- Engine: `zfa tdd verify` was NOT available for delegation (`zfa --version` works but `.zfa.json`
  is absent in this repo checkout), so per the TDD extension contract this is the **fallback
  LLM-guided audit**: test-first evidence from git history, recorded red-phase evidence,
  test-smell rubric, real mutation testing on the changed files, and acceptance-criteria
  coverage. Every claim below references a raw evidence file stored next to this document.

## Verdict: PASSED

- Red phase: 5 failing / 1 passing (evidence: `red-evidence.txt`)
- Green phase: 6/6 passing (evidence: `green-evidence.txt`)
- Scoped regression suites (test/plugins/di + test/plugins/mock): 75/75 passing
- Full fast suite (chunked, 74 chunks): 2908 passed / 0 failed / 4 chunks skipped for having
  no fast-tier tests (evidence: `full-suite-chunked.log`)
- Mutation testing on changed files: 6 applied / 6 killed / 0 survived (evidence:
  `mutation-results.txt`, per-mutant logs `mutant_M*.log`)
- `dart analyze`: 0 issues in changed files; repo-wide issue count identical to the clean
  master baseline (345 issues, all pre-existing, all under `examples/` which requires the
  Flutter SDK — verified by `git stash` → analyze → `git stash pop`)
- `dart format .`: idempotent after formatting (re-run reports `0 changed`, exit 0)

## 1. Test-first evidence (git history)

The test file was committed BEFORE the fix, on its own commit, with the red run recorded:

```
a0b7b052 test(1031): failing tests for service-mode simulation binding shape (RED)
          ^ test/plugins/di/simulation_service_binding_test.dart only — no lib/ changes
<fix commit> fix(1031): service-mode simulation binding follows the service shape (GREEN)
```

The RED commit message records the observed failure counts (5 failing / 1 passing). The
passing test in the red run is the datasource-lane guard, which must pass before and after
the fix — it pins the "do not change datasource-mode behavior" constraint.

## 2. Red-phase evidence (`red-evidence.txt`)

Run: `dart test test/plugins/di/simulation_service_binding_test.dart` against the unfixed
tree (`zfa mock create` in service mode, config `--name Auth --service Auth --params
AuthRequest --returns User --domain auth`).

Actual (buggy) behavior captured verbatim: the generated
`di/simulation/index.dart` contained `registerAuthSimulationDataSource(getIt);` and imported
`auth_simulation_datasource_di.dart` — the datasource-shaped binding referencing
`AuthDataSource` / `AuthMockDataSource`, classes never generated in service mode
(`uri_does_not_exist` at the consumer). Failing tests:

1. `emits a service-shaped simulation binding, not datasource-shaped`
2. `does not also emit the datasource-shaped binding in service mode`
3. `resolves a domain-scoped service interface import`
4. `wires the service binding into the simulation index`
5. `service and datasource bindings coexist in the simulation index`

Passing (pre-fix, by design): `datasource mode is unchanged: entity mock create still emits
the datasource-shaped binding`.

## 3. Green-phase evidence (`green-evidence.txt`)

Same command against the fixed tree: `00:00 +6: All tests passed!` The generated service
binding now reads exactly the expected shape:

```dart
void registerAuthSimulationService(GetIt getIt) {
  if (!kSimulationMode) return;
  getIt.registerLazySingleton<AuthService>(() => AuthMockProvider());
}
```

with imports resolved to where the service lane actually writes files
(`../../domain/services/auth_service.dart` or the domain-scoped variant, and
`../../data/providers/auth/auth_mock_provider.dart`), mirroring how the datasource lane binds
`<Entity>DataSource → <Entity>MockDataSource`.

## 4. Test-smell rubric

| Smell | Verdict | Notes |
| --- | --- | --- |
| Assertion-free / smoke-only tests | none | every test asserts generated file content or file presence/absence |
| Tautological tests (mirror the implementation) | none | assertions are on the emitted artifact text (public output), not on internal call graphs |
| Time/flaky dependencies (sleeps, real network, real clock) | none | pure temp-dir generation, `Directory.systemTemp` + `tearDown` cleanup |
| Shared mutable state between tests | none | fresh temp dir per test via `setUp` |
| Over-mocking | none | exercises the real MockPlugin → MockBuilder → SimulationBindingEmitter pipeline |
| Magic constants without reason | none | every `contains` assertion mirrors a contract line from the bug (function signature, flavor guard, binding target, import paths) |
| Negative assertions missing | present | asserts the datasource-shaped binding is NOT emitted in service mode and imports contain no `data/datasources` |
| Regression guard for unchanged behavior | present | datasource-lane test pins `<Todo>DataSource → <Todo>MockDataSource` shape and absence of a service-shaped file |

## 5. Mutation testing on changed files

Tool: hand-driven mutant matrix (the repo's `mutation_test` wiring scopes to the spec-041
TDD plugin files, not to these builders; the mutants below were applied one at a time to the
real working tree, the scoped suites
(`test/plugins/di/simulation_service_binding_test.dart` +
`test/plugins/di/simulation_binding_test.dart`) were actually executed against each mutant,
and the fixed file was restored from a snapshot between runs — logs: `mutant_M1.log` …
`mutant_M6.log`).

| Mutant | Site | Change (bug-equivalent behavior) | Result |
| --- | --- | --- | --- |
| M1 | `mock_plugin.dart` | drop the `config.hasService` branch — always emit datasource shape (the #1031 regression) | KILLED (exit 1) |
| M2 | `simulation_binding_builder.dart` | service binding file name reverts to `<snake>_simulation_datasource_di.dart` | KILLED (exit 1) |
| M3 | `simulation_binding_builder.dart` | function name reverts to `register<Name>SimulationDataSource` | KILLED (exit 1) |
| M4 | `simulation_binding_builder.dart` | binding target reverts to the concrete `<Name>MockProvider` type instead of the `<Name>Service` interface | KILLED (exit 1) |
| M5 | `simulation_binding_builder.dart` | domain-scoped service-interface import resolution removed (always flat path) | KILLED (exit 1) |
| M6 | `simulation_binding_builder.dart` | `if (!kSimulationMode) return;` flavor guard removed from the generated binding | KILLED (exit 1) |

Score: **6 killed / 0 survived / 0 timeout → no remediation tasks.**

## 6. Acceptance-criteria coverage

| Bug acceptance criterion | Covering test |
| --- | --- |
| Service mode emits `<Name>Service → <Name>MockProvider` simulation binding | `emits a service-shaped simulation binding, not datasource-shaped` |
| Generated function is `register<Name>SimulationService(GetIt)` behind `if (!kSimulationMode) return;` | same test (signature + guard assertions) |
| Binding imports classes the service lane really generates (no `uri_does_not_exist`) | same test + `resolves a domain-scoped service interface import` |
| Datasource-shaped binding/class references disappear in service mode | `does not also emit the datasource-shaped binding in service mode` (+ negative content assertions) |
| Simulation index stays in sync (detector is shape-agnostic) | `wires the service binding into the simulation index` + `service and datasource bindings coexist in the simulation index` |
| Datasource-mode behavior unchanged (hard constraint) | `datasource mode is unchanged: …` + untouched spec-893 suite `test/plugins/di/simulation_binding_test.dart` (7/7) + full suite green |
| One PR for the bug | branch carries exactly the test commit + this fix |

## 7. Evidence inventory

- `red-evidence.txt` — raw `dart test` output before the fix
- `green-evidence.txt` — raw `dart test` output after the fix
- `mutation-results.txt`, `mutant_M1.log` … `mutant_M6.log` — per-mutant raw test output
- `full-suite-chunked.log` — full fast-suite run (74 chunks, 2908 passed / 0 failed / 4 skipped)
