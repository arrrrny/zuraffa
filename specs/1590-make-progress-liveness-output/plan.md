# Implementation Plan: 1590-make-progress-liveness-output

**Branch**: `feat/1590-make-progress-liveness-output` | **Date**: 2026-09-13 | **Spec**: specs/1590-make-progress-liveness-output/spec.md

**Input**: Feature specification from `specs/1590-make-progress-liveness-output/spec.md`

## Summary

`zfa tdd run` is silent while a step runs (273.7s observed on one make).
The remediation is progress-output-only, layered by what each layer
genuinely knows: the DRIVER prints a step-start banner before each spawn
(static per-step hint) plus an elapsed-time heartbeat while the child
runs; the PIPELINE RUNNER prints a `→ ` banner before each sub-step spawn;
make's plan lines name the steps; a byte-faithful stdout line-tee in
`runTimed` lets the driver forward banner-shaped child lines live
(everything under `--verbose`). The machine contract
(`[run] <behavior> <step> -> <outcome>`, summary line, `--stream` NDJSON,
verdict envelope) stays byte-identical.

## Technical Context

**Language/Version**: Dart SDK ^3.11.0 (CLI package `zuraffa`)

**Primary Dependencies**: args, path — none added by this fix

**Storage**: N/A (output-only; run-state.json/transaction.json already
carry the in-flight trio — this feature only makes it VISIBLE, FR-007)

**Testing**: `dart test` (package:test), `dart analyze` lint gate,
`dart format` clean

**Target Platform**: Linux/macOS/Windows CLI (`zfa tdd run|run-engine|run-skin|make`)

**Project Type**: library/cli

**Performance Goals**: zero added spawns; the tee adds one stream
subscription per spawn (O(child lines)); heartbeat is one Timer per
running step

**Constraints**: byte-identical machine-contract output; NO change to step
execution logic, the state machine, or the test runner; no new analyzer
warnings; injected-spawner test fakes keep their own contract

**Scale/Scope**: 5 lib files (tdd_timeout, pipeline_runner, step_runner,
run_driver_core, make_command) + 3 command files (flag surface) + 1 new
fast-tier test file + 1 slow-tier suite extension; no schema changes

## Technical Context (domain notes)

- **Spawn topology**: driver (`RunDriverCore._driveBehavior`) →
  `StepRunner.run` → `runTimed` (Process.start, stdout/stderr joined) →
  step child (`zfa tdd make …`) → `PipelineRunner.runPlan` → `runTimed` →
  grandchild (`zfa tdd func`, `zfa build`). Everything the child/grandchild
  prints is captured today; nothing is printed before or during a spawn.
- **What each layer can honestly announce**: the driver knows the STEP
  (gen/verify-red/make/refactor) but NOT make's plan (built inside the
  child from the registry record + test list + spec declarations —
  duplicating that selection in the driver would drift). The pipeline
  runner knows each `GenerationStepSpec.args` the moment it spawns it. So:
  driver = step-start banner + heartbeat; pipeline = per-sub-step banners;
  the tee carries the child's authoritative announcements to the terminal.
- **Byte-faithful tee**: `runTimed` currently decodes
  `process.stdout` with `systemEncoding` and `.join()`. With the optional
  callback the SAME decoded stream feeds a `StringBuffer` while a
  carry-accumulator splits complete lines (`\n`, `\r\n` tolerated, final
  unterminated line flushed at done) and fires the callback — the returned
  string stays the concatenation of the decoded chunks, byte-for-byte.
- **Forward filter**: the driver prints tee'd lines only when they start
  with `→ ` (the FR-002 banner token, chosen so the make child's
  `plan:`/`make: ` summary lines and build noise stay captured); with
  `--verbose` it prints every line verbatim. `_parseSummaryLine` keys on
  `make: ` prefixes and `_parseGenVerdict` on final `{` lines — neither
  collides with `→ ` or the banner/heartbeat formats.
- **Heartbeat placement**: a `Timer.periodic` created immediately before
  `runner.run(…)` and canceled in a `finally` attached to the existing
  try/on-StateError block (the catch arm returns — `finally` still runs).
  Elapsed via a `Stopwatch` started at spawn; format via the existing
  `formatTddTimeout`. Interval: `--heartbeat <seconds>` (double parse,
  `0` = off, default 30s) parsed by a new helper beside
  `parseTddTimeoutMinutes` (same [TddTimeoutFormatException] contract).
- **In-flight visibility**: `RunState` already carries
  `inFlightBehaviorId/inFlightStep/inFlightOwnerPid`; `_driveBehavior`'s
  `current` parameter holds the LOADED state (pre-`markInFlight`), so
  `current.inFlightBehaviorId == row.id && current.inFlightStep == step &&
  current.inFlightOwnerPid != pid` identifies a resumed step exactly.
- **Flag surface lockstep**: `run`/`run-engine`/`run-skin` share
  `kStreamFlagHelp`/`kJsonFlagHelp` consts; this feature adds
  `kVerboseFlagHelp`/`kHeartbeatFlagHelp` the same way and threads
  `verbose`/`heartbeat` into `RunDriverCore.drive(...)` (named optionals,
  pre-#1590 defaults), which builds the single `StepRunner` (line ~540)
  and feeds `_driveBehavior` via instance state (the established
  `_streamFeature` pattern).
- **Machine contract**: documented at `run_command.dart` lines 33–41 and
  `run_driver_core.dart`'s library doc (the "byte-identical to the
  pre-split driver" claim gains an explicit #1590 carve-out listing the
  additive lines). Corpus/MCP parsers key on the FULL arrow pattern and
  JSON shapes; the additive lines match neither.

## Risks

- Interleaving: tee'd child lines and heartbeats share stdout with the
  contract lines. Mitigation: every new line is a single `print()` call
  (line-atomic); formats documented; `--heartbeat 0` for strict parsers.
- Test kernels: the slow-tier additions run in the existing fake-zfa
  fixture (no real builds); the heartbeat test uses sub-second sleeps.
- Byte-drift of captured output: covered by a fast-tier tee test asserting
  the returned `ProcessResult.stdout` equals the pre-#1590 join.
