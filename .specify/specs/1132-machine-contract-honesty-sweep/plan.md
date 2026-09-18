# Plan: 1132-machine-contract-honesty-sweep

- **Spec ID**: 1132-machine-contract-honesty-sweep
- **Created**: 2026-09-17

## Technical Context

- **Exit protocol (SPEC 917)**: `lib/src/cli/exit_protocol.dart` —
  `ExitProtocol.usage == 2` is the canonical usage-error code; the epic
  text's legacy `64` is retired (`canonicalize` maps it). The #856 pattern
  for multi-subcommand commands: bare invocation prints the subcommand
  grammar and sets `exitCode = ExitProtocol.usage`; explicit `--help`
  prints the same block and exits 0.
- **The six lying commands** are three shapes:
  - `Command<void>` classes with hand-rolled dispatch on
    `argResults!.arguments` (`benchmark` → `lib/src/plugins/benchmark/cli/benchmark_command.dart`
    run() head; `bone` → `lib/src/plugins/skeleton/bone_command.dart`);
    their bare/`--help` arm prints usage and returns, and bone's
    unknown-subcommand arm prints without setting exitCode.
  - Plain classes wrapped by `cli_runner.dart` shims with
    `ArgParser.allowAnything()` (`config` → `ConfigCommand.execute`,
    `plugin` → `PluginCommand.execute`); `config` calls hard `exit(0)` /
    `exit(1)` (embedded-dispatch unsafe) and files usage-class refusals
    under 1; `plugin`'s bare arm and "Missing plugin id" arm return/exit
    without the usage class.
  - `migrate` (`MigrateCommand.run()`) — bare → usage + return; unknown
    target → prose + usage, no exitCode at all.
  - `cli` (`_CliGeneratorCommand.run()` in
    `lib/src/plugins/cli/cli_plugin.dart`) — bare → `print('Usage: zfa cli
    <EntityName>'); return;`.
- **Canonical envelope (SPEC 1105)**: `lib/src/core/verdict_envelope.dart`
  — `VerdictEnvelope` with `schema: 'zuraffa.verdict.v1'`, verdict kinds
  `pass|fail|skip|error|stopped`, `exit_class`, `subject{kind,id}`,
  `artifacts`, `findings[{kind,fix,...}]`, `details` (the only free-form
  surface). `VerdictEnvelope.fromJson` THROWS on any other schema — the
  parser the lane-2 tests use. The emitter-scan guard
  (`test/core/verdict_envelope_emitter_scan_test.dart`) keeps an explicit
  `kExcluded` allow-list whose entries are the migration backlog.
- **The three divergent emitters**:
  - `lib/src/commands/capability_command.dart` ~L250: machine-mode
    missing-args refusal prints `{'schema': 1, 'ok': false, 'error', 'fix'}`
    before `exitCode = usage`. The SUCCESS half of the same path already
    routes through `CapabilityInvocationWrapper` (#996) which persists
    receipts (but check: does it emit a verdict envelope? — it does not;
    the success path's machine output is the wrapper's ExecutionResult
    summary, out of this lane's scope).
  - `lib/src/commands/provider_verify_command.dart` L80-82: `--json`
    prints `jsonEncode(report.toJson())` — the `ProviderVerifyReport`
    `{'schema': 1, ok, entity, providerFile, ...}` shape. In-process
    consumers (`make_command`, tdd compose) consume the Dart object, not
    the JSON — only the stdout encoding changes.
  - `lib/src/plugins/benchmark/cli/benchmark_command.dart` `_list()` and
    `_baselineCompare()`: `--json` prints `{'scenarios': [...]}` /
    comparison dump with no schema.
- **Receipts (proof.v1)**: `ReceiptStore(projectRoot).save(
  GenerationReceipt(command, target, repro, at, generatorVersion, input,
  files:[GenerationReceiptFile(path, action, sha256, bytes, snapshot)]))`
  — the #996 provenance contract `{plugin, capability, entity, hash,
  methodset, files, receipt_version: 1}`. Best-effort on success only.
  Two precedent implementations to copy: `_CliGeneratorCommand.run()`
  (cli_plugin.dart, direct) and `CapabilityInvocationWrapper`
  (capability_invocation_wrapper.dart, the generic seam).
- **The two receipt-less verbs**:
  - `zfa app shell` — `lib/src/commands/app_shell_command.dart` writes
    `app_router.dart`, the shell widget, optional skin kit/xray barrel/
    bridge stub and `lib/main.dart` via `FileUtils.writeFile` into
    `files` (List<GeneratedFile> with action create/overwrite/skipped);
    success is reported by `_logSummary(files)`. Receipt goes right
    after `_logSummary`, covering the non-skipped files.
  - `zfa skin kit` — `SkinKitCommand` in
    `lib/src/commands/skin_command.dart` writes
    `<output>/skin/skin_contract_auditor.dart` (preserved on re-run unless
    `--force`; a skip writes nothing → no receipt).
- **Openwiki generator**: `tool/generate_openwiki_cli_docs.dart` — parses
  the runner-level `zfa --help` "Available commands:" block with
  `RegExp(r'^  (\S+)\s{2,}(.*)$')` and BREAKS on the first continuation
  line (descriptions wrap at `kUsageLineLength = 120`,
  `lib/src/cli/usage_length.dart`), so today it captures 12 of 59
  commands. Fix: accept continuation lines (lines that are indented ≥ the
  command column and do not match a new command row) — the parser must
  return every command name. Per-command blocks come from
  `zfa <cmd> --help` (unwrapped subcommand help — stable).
- **Test seams**: `CliRunner(exitOnCompletion: false).runCapturing([...])`
  (in-process full CLI, returns stdout; `test/commands/
  standalone_invocation_receipts_test.dart` pattern) and the 1139 sweep's
  `runZoned` capture for command-object-level tests. Subprocess pins
  exist in `test/regression/issue_1132_slice_bare_exit_code_test.dart`
  (the model to extend per command).
- **Test tiers**: default `dart test` = fast unit; `@Tags(['e2e'])` runs
  in default tier; `@Tags(['regression','slow'])` needs
  `--preset=regression`. Plain `flutter test test/regression/` is the
  #1382 false-green (slow-tag excluded) — the honest epic criterion runs
  `dart test --preset=regression test/regression/`.
- **Language/SDK**: Dart 3.13.3 (Flutter 3.47.4 toolchain), pure-Dart
  package. `dart pub get --no-example` before `dart format lib test`
  before every commit (AGENTS.md).

## Architecture

```
Lane 1 (exit codes)    six commands ──▶ bare/unknown arm sets
                       exitCode = ExitProtocol.usage (2);
                       --help stays 0; config drops hard exit()
                       (exitCode only), exit classes corrected

Lane 2 (envelopes)     capability pre-flight ──┐
                       provider verify --json ──┼─▶ VerdictEnvelope
                       benchmark list/compare ──┘    (schema zuraffa.verdict.v1,
                       verdict/exit_class/subject real;
                       report payload rides in details;
                       findings carry fix lines) ──▶ removed from
                       kExcluded (emitter scan green)

Lane 3 (receipts)      app shell ──┐
                       skin kit  ──┴─▶ ReceiptStore.save(proof.v1)
                       after artifacts hit disk, success path only,
                       best-effort (failure warns, never flips green)

Lane 4 (docs)          parser fix (continuation lines) ──▶
                       regenerate docs/openwiki/cli.md from live
                       dispatcher ──▶ drift-guard regression test
                       (live --help commands ⊆ documented commands)

Verification           dart analyze + dart test (fast tier) +
                       dart test --preset=regression test/regression/ +
                       subprocess fleet sweep (exit-code audit script) +
                       fixture receipts demo + docs regeneration diff ──▶
                       tdd/verification.md (REAL runs, this session)
```

## Implementation Plan

1. **RED**: write the four test files (one per lane, see
   `tdd/test-list.md`); run each against unmodified master; record the
   failures as red evidence (they must fail for exactly the audited
   reason).
2. **Lane 1 GREEN**: patch the six commands (usage arms set
   `ExitProtocol.usage`; help arms stay 0; config/plugin lose hard
   `exit()`; exit classes corrected). Subprocess-level pins extended in
   the regression tier.
3. **Lane 2 GREEN**: build `VerdictEnvelope`-shaped envelopes in the three
   emitters (payload in `details`), keep text mode unchanged, remove the
   three `kExcluded` entries.
4. **Lane 3 GREEN**: append receipt writes to `app shell` and `skin kit`
   success paths (digest from disk bytes, only files actually written).
5. **Lane 4 GREEN**: fix the generator parser, extract it as a pure
   function usable by tests, regenerate `docs/openwiki/cli.md`, add the
   drift-guard regression test.
6. **Verify**: analyze/format/fast tier/regression tier/fleet
   sweep/receipts demo; write `tdd/verification.md` from the real runs;
   conventional commits per lane; push; PR.
