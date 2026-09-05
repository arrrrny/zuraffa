# Plan: 0974-di-a-plus-upgrade

## Current architecture (read from the tree)

- `zfa di` → `ModularDiCommand` (lib/src/commands/modular_di_command.dart)
  auto-registers every `DiPlugin.capabilities` entry as a subcommand via
  `PluginCommand`/`CapabilityCommand` (subcommand grammar `zfa di create|register`).
- `lib/src/commands/di_command.dart` — 427 LOC `DiCommand` with its own divergent
  regex usecase analyzer; ZERO importers anywhere (verified by grep across
  dart/md/yaml/json/sh). Truly dead.
- `CreateDiCapability.execute` / `RegisterCapability.execute` build a
  `GeneratorConfig`, call `DiPlugin.generate`, then hardcode
  `ExecutionResult(success: true, ...)` — generation failures propagate as
  uncaught exceptions or empty-file successes.
- Receipts: `PluginManager._persistGenerationReceipt` writes a `proof.v1`
  `GenerationReceipt` through `ReceiptStore` for `zfa make` runs ONLY. The
  standalone capability path writes nothing.
- `zfa proof check` → `ProofChecker.check()` re-derives digests for every
  receipted artifact (latest-wins per path).

## Implementation steps

### T001 — delete the dead command (RED → GREEN)
- RED: `test/plugins/di/dead_command_gone_test.dart` asserts the file does not
  exist and no source under `lib/` references `di_command.dart`. Fails first.
- GREEN: `git rm lib/src/commands/di_command.dart`. No rewiring needed
  (zero importers verified pre-hoc).

### T002 — `zfa di verify` gate (RED → GREEN)
- New `DiVerifyCapability` (lib/src/plugins/di/capabilities/verify_capability.dart)
  auto-registered as the `verify` subcommand.
- Algorithm: scan `<outputDir>/di/**/*.dart`; extract every `getIt<T>(` and
  `getIt.registerXxx<T>(` type reference; index every class/mixin/enum/typedef
  declared in `*.dart` under `<projectRoot>/lib`; check every relative import
  of each DI file exists on disk. Any type that resolves nowhere → dangling
  binding finding: file, class, expected conventional file,
  `--> fix:` hint. Non-empty findings → `success: false` (CLI exit 1 via
  `CapabilityCommand`). Missing `di/` tree → success (nothing to verify).
- `projectRoot` defaults to `Directory.current.path`; injectable for tests.

### T003 — standalone receipts (RED → GREEN)
- Shared `DiReceiptWriter` writes a `proof.v1` receipt through `ReceiptStore`
  after `zfa di create/register` actually writes files (not dry-run, not
  revert, at least one created/overwritten/updated file).
- Receipt: `command: 'di'`, `target: <name>`, `repro: 'zfa di create <name>'`,
  generatorVersion, `input` = capability args + plugin id + index sha256,
  `files` = every written registration + index file with on-disk sha256/bytes/
  snapshot (same shape as `PluginManager._persistGenerationReceipt`).
- Best-effort (try/catch → warning) so receipt failure degrades, matching the
  make path.

### T004 — real verdicts (RED → GREEN)
- `ExecutionResult` gains `warnings` (structured `List<Map<String, dynamic>>`,
  each `{target, reason}`; serialized when non-empty).
- `CreateDiCapability.execute`/`RegisterCapability.execute`: wrap generation in
  try/catch → exception ⇒ `success: false` + message; skipped files ⇒
  structured warnings `{target: path, reason: 'exists (use --force)'}`;
  zero files ⇒ warning `{target: name, reason: ...}` and success reflects it.
- Forced-failure test drives a throwing `FileSystem` fake through the real
  plugin.

### T005 — docs
- `openwiki/data-layer.md` DI section: replace the `zfa di <UseCaseName>`
  positional-grammar row with the live subcommand grammar + verify gate.
- `ModularDiCommand` option help: mention the subcommand grammar and
  `verify` in the description where useful; `.specify` `di.md` command doc
  updated to the subcommand grammar.

### T006 — refactor + verify
- `dart format`, `dart analyze` (zero NEW issues vs the 345-issue baseline),
  `tools/run_tests_chunked.sh` green, `dart format .` → zero diff.
- `/speckit.tdd.verify` → `specs/0974-di-a-plus-upgrade/tdd/verification.md`
  from the REAL runs of this session.

## Risks / non-goals

- Simulation-binding emission (spec 893) is NOT touched.
- No behavior change to `zfa make` receipts.
- The verify gate uses textual type-reference resolution (regex) over the
  generated-code contract, not the full analyzer — matching the failure modes
  #284/#410 actually produced (class never emitted / import URI dead).
