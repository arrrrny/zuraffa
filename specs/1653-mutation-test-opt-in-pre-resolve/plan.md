# Plan: 1653-mutation-test-opt-in-pre-resolve

**Technical Context**: Dart 3.13 (SDK `^3.11.0`), the `zfa` CLI shipped by
this very package. The surfaces touched are the TDD plugin's init/preflight
writer chain (`lib/src/plugins/tdd/services/baseline_init.dart`,
`lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`,
`lib/src/plugins/tdd/commands/init_command.dart`) and the refactor receipt
chain (`lib/src/plugins/tdd/commands/refactor_command.dart`,
`lib/src/plugins/tdd/services/refactor_passes.dart`,
`lib/src/plugins/tdd/models/refactor_action.dart`,
`lib/src/plugins/tdd/models/cycle_entry.dart`). No Flutter-only surface is
touched; the whole feature is pure Dart (CORE lane).

## Root cause (from the issue's evidence + code read)

`PubspecDevDependenciesPatcher.flutterDevDependencies` /
`.dartDevDependencies` both carry `mutation_test: ^1.8.0`
(`lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:49,57`), and
`TddBaselineInit.ensure` (the #1528 preflight's writer sequence) injects
them unconditionally. `mutation_test` is analyzer-versioned: injecting it
enlarges the package config, so the first analyze-class pass after init pays
dependency download/resolution + first analysis over the enlarged graph —
the 8m32s cold cost. Warm (26–44s) on every subsequent refactor because the
caches persist. The cost recurs per fresh project / fresh CI agent.

Secondarily, the refactor receipt (`CycleLogEntry`, kind `refactor`) records
verdicts and actions but NO per-phase durations — the cycle-log entry "records
no per-phase durations; without heartbeats the 8m32s would be
indistinguishable from a stuck step".

## Design decisions

1. **Opt-in switch on the writer** (FR-001): `includeMutationTest` named
   parameter on `PubspecDevDependenciesPatcher`, DEFAULT FALSE. The static
   maps keep their `mutation_test` entries — the bug #755 pin contract
   (`^1.8.0` matching MutationVerifier) is asserted unchanged; the switch
   only filters the injected set. This makes `zfa setup` (the other
   patcher caller) stop injecting `mutation_test` too — the same fresh-app
   cold-cost class, desirable per SC-4.
2. **Threading through the baseline init** (FR-002/003):
   `TddBaselineInit.ensure({..., bool mutation = false})` →
   `PubspecDevDependenciesPatcher(isFlutter: isFlutter,
   includeMutationTest: mutation)`. `InitCommand` adds `--mutation`
   (negatable: false) forwarding the opt-in. The #1528 preflight
   (`TddProfilePreflight`) keeps the default — auto-init on the first
   `zfa tdd run` is exactly the fresh-project path the issue indicts.
3. **Pre-resolve service** (FR-004/005): new
   `lib/src/plugins/tdd/services/pub_pre_resolver.dart` —
   `PubPreResolver.resolve({projectRoot, isFlutter, onLine})` spawns
   `dart pub get --no-example` (or `flutter pub get --no-example`) under
   `TddTimeouts.defaultPipelineStep`, returns the elapsed `Duration` +
   exit outcome. `TddBaselineInit` calls it ONLY when the dependency
   writers added something (dev-deps patcher returned non-empty, or the
   #1349 app-deps patcher did, or the #1260 skin patcher did). Resolver
   ran + non-zero exit → writer failure (misfire, fail-closed). Binary
   missing (`dart`/`flutter` not on PATH) → loud warning, no misfire.
   Injectable spawn seam (`runProcess`) for tests — no real pub get in
   unit tests.
4. **Phase timing in the refactor command** (FR-006): three
   `Stopwatch`es around (a) the preflight `runSuite`, (b) `passes.run()`,
   (c) the re-proof block INCLUDING #1333 retries (first attempt start →
   last completion). A `_phaseTimings` map prints as
   `   phase timings: preflight=1.2s registry=3.4s re-proof=2.1s` on the
   green path just before `_printSummary`, and rides the cycle-log entry.
   The FR-009 summary line format is untouched.
5. **Per-pass duration** (FR-008): `RefactorAction.duration` (optional
   `Duration?`); `RefactorPasses.run()` measures executor wall time per
   pass (null for a scheduling-skipped pass — nothing ran).
6. **Additive rendering** (FR-007): `CycleLogEntry` gains an optional
   `Map<String, Duration>? phaseDurations`; for kind `refactor` it renders
   `- phases: preflight=<d> registry=<d> re-proof=<d>` after the `- at:`
   line; each action renders `  duration: <d>` inside the `actions:` block
   when non-null. Duration format: `1.2s` under a minute, `1m02s` above.
   Both lines sit OUTSIDE the chain-hash payload (the `- outcome:` /
   `- subject-hash:` / #1587-note precedents) — schema stays v1, legacy
   entries keep parsing, the doctor's recompute is untouched.

## Concurrency/compat hazards checked

- `CycleLogEntry.toMarkdown` is consumed by `CycleLog` (append) and parsed
  by the doctor's evidence walk + the #1612 hash recompute. Additive lines
  after `- at:` are outside the certified-facts set the payload covers;
  the existing parsers are line-tolerant (the `outcome` precedent proves
  the shape).
- `RefactorPassesResult`/`RefactorAction` constructors are value objects;
  the new optional fields default null — every existing call site and the
  #1624/#1540 synthetic actions compile unchanged.
- The patcher's dry-run contract (used by `zfa setup --dry-run`) filters
  identically (the wanted-map is computed once).
- The #1528 preflight passes NO mutation flag → fresh auto-init projects
  get no `mutation_test`; `zfa tdd verify` on such a project degrades to
  its existing NOT_ASSESSED + fix line (unchanged behavior, honest).

## Verification strategy

1. RED first: new test file
   `test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart` (patcher
   default/opt-in, init threading, pre-resolve fire/skip/misfire/warn,
   `--mutation` CLI wiring) and
   `test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart` (per-pass
   duration + cycle-entry additive rendering + green-path timings line).
   Record the real red output in `tdd/cycle-log.md` (red evidence) BEFORE
   implementing.
2. GREEN: implement, re-run both files to green; record green evidence.
3. Targeted regression: the pre-existing suites that touch the changed
   surface — `pubspec_dev_dependencies_patcher_test.dart`,
   `bug_1349_init_flutter_app_deps_test.dart`,
   `bug_1370_flutter_consumer_test_baseline_test.dart`,
   `refactor_command_test.dart` (subset), `bug_828_cycle_log_evidence_integrity_test.dart`,
   `bug_1327_cycle_log_terminal_receipt_test.dart`.
4. Real mutation evidence: scoped `mutation-test.xml`-style config over the
   eight changed lib files with the covering test scope, run
   `dart run mutation_test` for real; the report lands in
   `tdd/verification.md` with the real counts.
5. `dart analyze` (changed files) + `dart format` + summary-line
   byte-compat spot check.
