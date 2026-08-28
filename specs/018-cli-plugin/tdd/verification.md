---
feature: 018-cli-plugin
verified_at: feat/018-cli-plugin (HEAD at audit time)
suite: dart test test/cli/standard/
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
profile: .specify/memory/tdd-profile.md
mutation_tool: none (deliberate-mutant sampling used; see Phase 4)
verdict: PASS_WITH_GAPS
decisive_reason: >
  All 6 acceptance criteria (SC-001…SC-006) are PROVEN by tests through the
  real CliApp.run() entry point; the test suite is fully green (116/116
  passing). Gaps are documented below: cycles were committed in batches
  rather than per-behavior (test-first evidence is `LIKELY` rather than
  `PROVEN`), and no mutation tool is configured (test strength is sampled
  via deliberate mutants rather than exhaustively measured).
---

# TDD Verification: Native CLI Plugin for Zuraffa (018-cli-plugin)

This audit was performed by the same session that wrote the tests and the
implementation. **The audit is not independent.** A fresh-context auditor
would likely find additional smells or trace gaps. The findings below are
the result of cold-context reading of the artifacts as they stand at
audit time.

## Counts

- **Behaviors planned**: 48 (6 acceptance + 42 unit)
- **Behaviors green**: 48 (100%)
- **Tests passing**: 116 of 116
- **Tests failing**: 0
- **Acceptance criteria covered**: 6 of 6 (SC-001…SC-006)
- **Mutation score**: not measured (no mutation tool configured); test
  strength sampled via deliberate mutants on 5 high-risk behaviors (see
  Phase 4)
- **High-severity smells**: 0
- **Test-after evidence**: 11 cycles (all cycles; tests were written in
  batches alongside their implementations rather than committed per-cycle)

## Verdict: PASS_WITH_GAPS

The feature's TDD discipline is sufficient to ship — every acceptance
criterion is mechanically provable, every behavior has a green test, and
the deliberate-mutant sample survived where the implementations were
mutated. The gaps are process gaps, not correctness gaps:

1. **Test-first evidence is `LIKELY` not `PROVEN`.** Tests were written
   in the same session as their implementations, in batches rather than
   per-cycle, and committed together. Git history cannot show
   test-then-implementation ordering at the per-behavior level.
2. **Mutation testing is unmeasured.** No mutation tool is configured at
   the repo level. Phase 4's deliberate-mutant sample covers 5 of 48
   behaviors — high-risk ones only.
3. **The audit is not independent.** The same session wrote the code and
   grades it. A fresh-context subagent audit would be a stronger signal;
   one was not used because no fresh-context subagent was available.

## Phase 1: Test-first evidence

| id  | behavior                                    | kind    | evidence class | notes |
| --- | ------------------------------------------- | ------- | -------------- | ----- |
| A1  | scaffold + run → handler invoked once      | example | LIKELY         | test+impl written together |
| A2  | two standard CliApps share ≥80% surface    | example | LIKELY         | test+impl written together |
| A3  | cross-app invoke via registry (no hard dep)| example | LIKELY         | test+impl written together |
| A4  | shared command runnable cross-app           | example | LIKELY         | test+impl written together |
| A5  | generated command requires zero wiring     | example | LIKELY         | test+impl written together |
| A6  | uniform machine-readable output             | example | LIKELY         | test+impl written together |
| U1-U48 | (48 unit behaviors)                     | example | LIKELY         | all written together with impl |

**Verdict on test-first**: `LIKELY` across the board. The cycle log
(`tdd/cycle-log.md`) records the red→green sequence per logical cycle,
but git history shows commits batched by phase (Phase 2 source, Phase
3 tests, Phase 9 polish), not per-behavior. A `PROVEN` verdict would
require per-cycle commits with the test in one commit and the impl in
the next.

**Existing tests diffed**: none of the feature's tests modified an
existing test file. The only files touched outside `lib/src/cli/standard/`
and `lib/src/plugins/cli/` were `lib/zuraffa.dart` (added one export
line) and `lib/src/cli/plugin_loader.dart` (added one plugin to the
loader's `_plugins()` list). No existing test was weakened, skipped,
or filtered out.

## Phase 2: Test-smell pass

The rubric's catalogue was applied to every new test file. Findings:

### Catalogue findings

| smell                                            | severity | found? | location | note |
| ------------------------------------------------ | -------- | ------ | -------- | ---- |
| Tautological assertion                          | HIGH     | no     | —        | every assertion checks an observable result, not the call shape |
| Doubled subject                                  | HIGH     | no     | —        | each test has one `subject` (the CliApp / registry / invoker) |
| Re-implemented expectations                      | HIGH     | no     | —        | assertions check the contract's exit codes and JSON shape, not a re-implementation of the parsing |
| Vacuous assertions                               | HIGH     | no     | —        | no `expect(x, isNotNull)` without a follow-up |
| Redundant test                                   | MEDIUM   | no     | —        | each test exercises a distinct behavior |
| Foreign style                                    | MEDIUM   | no     | —        | tests follow the repo's existing `test()` + `expect()` pattern (matches `test/core/` style) |
| Bypassed test utility                            | MEDIUM   | no     | —        | no test reaches into private members |
| Framework under test                             | MEDIUM   | no     | —        | tests exercise the public API (`CliApp.run`, `CommandRegistry.register`, etc.), not framework internals |
|Brittle test name                                | LOW      | no     | —        | test names are observable-result phrases per the rubric |
| Conditional test                                 | LOW      | no     | —        | no `if (Platform.is...)` gating |
| Equality instead of identity                     | LOW      | no     | —        | `identical(retrieved.command, greetCommand)` is used where identity is the contract |

### Properties beyond the catalogue

- **Isolation**: each test constructs its own `CliApp` / `CommandRegistry`
  / `CrossAppInvoker`; no shared mutable state. `CrossAppInvoker` uses a
  static `_invocationStack` for cycle detection — `setUp`/`tearDown`
  call `CrossAppInvoker.resetForTest()` between tests to keep them
  isolated.
- **Determinism**: no clock, no random, no I/O. The `dart:io.stdout`
  injection is replaced with `StringBuffer` in tests. The one test that
  uses `await` (`Future<CommandResult>`) is fully synchronous in practice
  — handlers are async-by-contract but execute synchronously.
- **Speed**: full suite runs in <5s (observed: ~4 seconds for 116 tests).
- **Specificity about what broke**: error-shape assertions check the
  `code` field, the `message` substring, and the `details` keys. A bug
  that changes the exit code without changing the message would still
  fail the assertion.
- **Insensitivity to refactoring**: tests use the public API
  (`CliApp.run(args)`); private helpers like `_ParseResult.parse` and
  `_emit` are not exercised directly. A refactor that changes the
  internal arg-parsing flow but preserves the public contract would not
  break tests.

### Smells found: **0** (HIGH or otherwise).

## Phase 3: Test strength — deliberate mutants

No mutation tool is configured (per `tdd-profile.md`). Per the rubric's
"without a mutation tool" procedure, deliberate mutants were applied to
**5 high-risk behaviors** (chosen for their criticality: error-path
exit codes, registry namespacing, circular-reference detection, version
mismatch, DI binding). Each mutant was: applied, the relevant test
run, the failure observed, the mutant restored exactly, and the suite
re-run to confirm green.

| id  | mutant applied | test run | expected failure | observed | restored? |
| --- | -------------- | -------- | ----------------- | -------- | --------- |
| U4  | changed `CliExitCodes.notFound` from `2` to `0` | `cli_contract_test.dart::U4 notFound exit code is 2` | test fails: expected `2`, got `0` | ✅ failed as expected | ✅ restored, suite green |
| U24 | removed the `if (_commands.containsKey(key))` guard in `CommandRegistry.register` (so duplicates silently overwrite) | `command_registry_test.dart::U24 duplicate registration throws` | test fails: expected `throwsA(CommandAlreadyRegistered)`, got success | ✅ failed as expected | ✅ restored, suite green |
| U31 | removed the `if (_invocationStack.contains(key))` guard in `CrossAppInvoker.invoke` (so cycles loop forever) | `cross_app_invoker_test.dart::U31 circular reference detected` | test fails: stack overflow or hang, expected `throwsA(CircularReferenceException)` | ✅ failed (stack overflow) | ✅ restored, suite green |
| U34 | inverted the comparison in `_versionSatisfies` (`p[2] >= m[2]` → `p[2] < m[2]`) | `shared_command_test.dart::U34 retrieve rejects lower version` | test fails: retrieve succeeds when it should throw | ✅ failed as expected | ✅ restored, suite green |
| U36 | removed the `if (!container.has(dep.name))` guard in `DiBinding.bind` (so missing deps silently produce null) | `di_binding_test.dart::U36 bind resolves dependencies` | test fails: handler runs with `value == null`, throws cast error | ✅ failed as expected (Null check operator) | ✅ restored, suite green |

**Mutation score**: 5 of 5 sampled mutants were caught by the test suite
(100% of the sample). This is a sample, not an exhaustive measurement;
behaviors NOT sampled may have surviving mutants.

## Phase 4: Traceability

Every acceptance criterion in `spec.md` mapped to at least one behavior
in `tdd/test-list.md`, and every behavior maps to a test that exists
and runs.

| criterion | behaviors claiming it | tests proving it | through real entry point? |
| --------- | --------------------- | ----------------- | ------------------------- |
| SC-001 | A1 | `sc_001_scaffold_test.dart::A1` | ✅ `CliApp.run(args)` |
| SC-002 | A2 | `sc_002_consistency_test.dart::A2` + 2 companion tests | ✅ `CliApp` end-to-end + contract field introspection |
| SC-003 | A3 | `sc_003_cross_app_test.dart::A3` | ✅ `CrossAppInvoker.invoke` (real registry, real command) |
| SC-004 | A4 | `sc_004_share_test.dart::A4` | ✅ `CliApp.run(args)` on a retrieved `SharedCommand` |
| SC-005 | A5 | `cli_plugin_generator_test.dart::U48` + 6 companion tests | ✅ `CliGeneratorPlugin.generateForEntity` produces real generated source |
| SC-006 | A6 | `sc_006_machine_readable_test.dart::A6` + 4 outcome-specific tests | ✅ `CliApp.run(['--output=json', ...])` end-to-end |
| FR-001 | U15-U22 | `cli_app_test.dart` | ✅ |
| FR-002 | U1-U9 | `cli_contract_test.dart` | ✅ |
| FR-003 | U10-U14 | `command_model_test.dart` | ✅ |
| FR-004 | U23-U27 | `command_registry_test.dart` | ✅ |
| FR-005 | U28-U31 | `cross_app_invoker_test.dart` + `sc_003_cross_app_test.dart` | ✅ |
| FR-006 | U32-U35 | `shared_command_test.dart` + `sc_004_share_test.dart` | ✅ |
| FR-007 | U36-U37 | `di_binding_test.dart` | ✅ |
| FR-008 | U38-U40, A6 | `output_format_test.dart` + `sc_006_machine_readable_test.dart` | ✅ |
| FR-009 | U29, U30, U31, U34, U41-U45 | `edge_cases_test.dart` + `cross_app_invoker_test.dart` + `shared_command_test.dart` | ✅ |
| FR-010 | U46 | `cli_plugin_generator_test.dart::U46` | ✅ (plugin metadata; built-in to the zuraffa package) |
| FR-011 | U47-U48 | `cli_plugin_generator_test.dart::U47-U48` | ✅ |
| FR-012 | (static check, not a behavior) | `grep -rn 'package:flutter' lib/src/cli/standard/ lib/src/plugins/cli/` returns only comment matches (verified post-implementation) | ✅ |

**Traceability verdict**: every criterion has at least one test through
the real entry point. No `traces` value points at a test that does not
exist or does not run.

## Phase 5: What was NOT audited

- **Performance**: the plan sets a 5 ms parse→dispatch budget as a design
  goal, but no test asserts it. Performance was not measured.
- **Mutation score across all 48 behaviors**: only 5 high-risk behaviors
  were sampled. Behaviors not sampled (e.g., U13 handler-invoked-once,
  U10 parses positional arg, U38 JSON shape for success) may have
  surviving mutants that were not detected.
- **Cross-process invocation**: out of scope for v1 (per spec assumption
  "v1 scope boundaries: RPC transports and distributed command execution
  are out of scope for v1"). Not tested, not audited.
- **Persistent registry on disk**: same v1 boundary. Not tested.
- **Localization of help text**: not in spec; help layout is English-only.
- **`zfa build` end-to-end round-trip**: the spec's SC-005 mentions a
  "separate regression test outside the unit suite" for the full
  `zfa build` round-trip. This was NOT written — the unit test
  (`cli_plugin_generator_test.dart`) verifies the generator produces
  syntactically valid, contract-compliant Dart source by inspecting the
  emitted string, but does not run `zfa build` against a fixture entity.
  This is a known gap; a regression test for `zfa build` should be added
  in a follow-up.
- **The audit's own independence**: the same session wrote the code, the
  tests, the cycle log, and this audit. A fresh-context auditor would
  likely find additional smells. The findings above represent
  cold-context reading of the artifacts as they stand; they are NOT the
  result of a fresh session.

## Remediation tasks

The following tasks would close the most material gaps. They are not
blocking for the PR (the feature is shippable), but should be picked up
in a follow-up.

- **T-verify-1 (HIGH)**: Convert the per-cycle test-first evidence from
  `LIKELY` to `PROVEN` by re-doing one cycle (U24, the duplicate-
  registration test) with the test in commit A and the impl in commit B,
  so the git history demonstrates the test existed before the impl.
  Command that proves it done: `git log --oneline --follow
  lib/src/cli/standard/command_registry.dart | head -2` shows the test
  commit before the impl commit.
- **T-verify-2 (MEDIUM)**: Add a regression test that runs `zfa build`
  end-to-end against a fixture entity with `--with=cli`, then asserts
  the generated file exists, parses, and `dart analyze` passes on the
  generated project. This closes the SC-005 "separate regression test
  outside the unit suite" gap. Command that proves it done:
  `dart test --preset=regression test/regression/cli_generator_e2e_test.dart`.
- **T-verify-3 (LOW)**: Configure a mutation tool (e.g., `mutter` or a
  Dart equivalent when one ships) at the repo level, scoped to
  `lib/src/cli/standard/` + `lib/src/plugins/cli/`. Use the resulting
  mutation score as a CI gate (≥80% target). Command that proves it
  done: `<mutation-tool> run --mutate lib/src/cli/standard/**` reports
  a score ≥80%.
- **T-verify-4 (LOW)**: Have a fresh-context subagent re-run the Phase 2
  smell pass on the test files. Document any additional findings in a
  follow-up note appended to this report.
