# Plan: 1147-spec-fuzz-mutation-arena

- **Spec ID**: 1147-spec-fuzz-mutation-arena
- **Created**: 2026-09-18

## Technical Context

- **The arena already exists (spec 0967-spec-mutation-arena, issue #967)**:
  `zfa spec fuzz` is implemented end to end — `SpecMutator`
  (`lib/src/plugins/tdd/services/spec_mutator.dart`) generates deterministic
  `SM-###` candidates per contract element and applies them by line surgery;
  `SpecFuzzAuditor` (`lib/src/plugins/tdd/services/spec_fuzz_auditor.dart`)
  referees each mutant through the P1 plan-gate / P2 loop-red / P3 assertion
  pins with byte-exact restore; `SpecFuzzCommand`
  (`lib/src/plugins/tdd/commands/spec_fuzz_command.dart`) exposes the CLI
  (`--operators`, `--budget`, `--seed`, `--json`, `--project`, `--timeout`,
  `--runner`, `--no-ledger`, `--corpus`) with the exit protocol
  0/1/2/3/64. Issue #1147 (VISION-3, EPIC #1136) EXTENDS #967: the five
  operators, the machine-readable weakness report
  `{mutation_id, spec_line, operator, verdict, evidence}`, exit 0 only when
  every mutant is killed, and `--budget N` are the contract this spec pins.
- **The gap this spec closes — the fast tier cannot prove the CLI run
  semantics**: `SpecFuzzAuditor` takes injectable `runPreflight` /
  `spawnTest` seams (the MutationAuditor pattern) and its unit suite is
  fast; `SpecFuzzCommand`, however, constructs the auditor with REAL spawns
  only, so every existing CLI-level test stops at usage/drift/corpus
  refusals. The run semantics — exit 0 all-killed vs exit 1 survived>0, the
  report rows the issue documents, `--budget N` respected at the command
  boundary, and byte-identical replay — are proven only by the slow-tier
  demo (`spec_fuzz_demo_test.dart`, real `dart test` subprocesses,
  `@Tags(['slow', 'integration'])`), which the default `dart test` lane
  excludes. The 1147 constraints therefore have no fast-tier red/green
  evidence at the layer that parses the flags and sets the exit code.
- **The minimal delta — thread the existing seam through the command**:
  add optional, named injection parameters to `SpecFuzzCommand`
  (`runPreflight`, `spawnTest`, mirroring the auditor's own parameter
  shapes) and pass them through `SpecCommand`'s constructor. Both default
  to null = today's real-process behavior byte-for-byte: the CliRunner
  wiring (`lib/src/cli/cli_runner.dart` -> `SpecCommand()` ->
  `SpecFuzzCommand()`) is untouched, no existing call site changes
  semantics, and the "do NOT change existing tdd run semantics" hard
  constraint holds (the command's body, flags, gates, and exit protocol
  are unmodified; only the construction gains optional seams).
  Fast-tier tests then drive the REAL command through a local
  `CommandRunner('zfa','test')` with the honest fake spawn (the
  `spec_fuzz_auditor_test.dart` convention: read the regenerated test,
  compare its `equals(<n>)` pin against the paired subject, red on
  mismatch, green on no pin).
- **Why the fake spawn is honest evidence**: the fake emulates exactly the
  P2 oracle contract — the mutant's regenerated test run against the
  committed implementation — with deterministic inputs, so killed/survived
  classification, evidence lines, gate precedence, ledger integration, and
  report bytes are all judged by the real auditor code path; the slow demo
  remains the real-process corroboration (re-run in this session as
  verification evidence).
- **The five operators against the fixture spec** (the issue's operator
  table, executable): weaken targets the Then clause's quoted literal
  ("shows the message 'Hello'" -> "shows the message something"); drop
  targets the edge-case scenario (empty name); swap-literal targets the
  quoted literal and declared numbers; widen targets the FR range
  (`0..100` -> `0~/2..100*2`); drop-must-not targets the MUST NOT clause.
  A fixture spec carrying all five element types yields candidates for
  every operator — the per-operator determinism pin.

## Remediation

`lib/src/plugins/tdd/commands/spec_fuzz_command.dart` — ONE command, ONE
constructor:

- `SpecFuzzCommand({super-optional runPreflight, spawnTest})` — two new
  optional named parameters with the auditor's exact typedefs, stored and
  forwarded to the `SpecFuzzAuditor` construction site in `_run` (and the
  per-feature construction site in `_runCorpus` for symmetry). No body
  logic changes.
- `lib/src/commands/spec_command.dart` — `SpecCommand({runPreflight,
  spawnTest})` forwards to the fuzz command (the spec family hosts one
  subcommand today; the passthrough keeps the construction seam at the
  family boundary).

`test/commands/spec_fuzz_command_1147_run_semantics_test.dart` — the
fast-tier CLI run-semantics suite (test-first, red before the seam):
exit codes, report shape, operator filter, budget cap, byte-identical
replay, per-operator candidate presence, and the honest refusals that
gate them.

## Verification Plan

- Red: the new suite fails to resolve the injection seam before the fix
  (compile-error red — the honest first red for a NEW seam, the #1664
  convention); recorded in the cycle log.
- Green: `dart test test/commands/spec_fuzz_command_1147_run_semantics_test.dart`
  plus the untouched sibling suites (`spec_fuzz_command_test.dart`,
  `spec_fuzz_auditor_test.dart`, `spec_mutator_test.dart`) — no existing
  test changes.
- Real-process corroboration: the slow-tier seeded-weakness demo
  (`spec_fuzz_demo_test.dart --tags slow`) re-run end to end in this
  session — weak fixture survives (exit 1, ledger gaps, restored spec),
  strong fixture kills all (exit 0, certified), byte-identical replay.
- `dart analyze` on the touched files; `dart format .` clean.
