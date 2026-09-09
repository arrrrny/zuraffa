# Implementation Plan: zfa proof chain — end-to-end receipt validation with JSON verdict

**Branch**: `1334-proof-check-end-to-end-validation` | **Date**: 2026-09-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/1334-proof-check-end-to-end-validation/spec.md`

## Summary

A new read-only `zfa proof chain` subcommand (issue #1148, VISION-4, EPIC 5)
walks `.zfa/receipts/` and the project tree and validates the six links of
the proof chain: (1) receipt digests match disk files (reuses the #807
`ProofChecker` engine by composition), (2) spec behaviors have green
cycle-log evidence, (3) tdd gen'd tests exist and their imports resolve
(`--run-tests` adds real execution), (4) declared route tables have
passing/skipped verify verdicts, (5) usecase-create receipt entities pass
the in-process conformance gate, (6) ui-ledger coverage kinds are traced by
green evidence. The verdict is one `proof-chain.v1` JSON object with
category/severity/file/expected/actual/fix per item; exit codes 0 (intact),
1 (drift), 2 (infra) per SPEC 917. The existing `zfa proof check` (#807) is
untouched.

## Technical Context

**Language/Version**: Dart 3.11+ (SDK constraint `^3.11.0`; developed
against Dart 3.13.3 stable)

**Primary Dependencies**: `args` (CLI parsing), `crypto` (SHA-256),
`path`, in-repo subsystems below. No new external packages.

**Storage**: reads only — `.zfa/receipts/*.json` (proof.v1 generation
receipts via `ReceiptStore.loadAll`, test.v1 via `TestReceiptStore`,
`routes-<Entity>.json` route tables, `routes-<Entity>-verify.json` route
verify verdicts with top-level `verdict.ok`, `usecase-create-<entity>-
<timestamp>.json` capability receipts with `plugin=usecase`), and the tdd
stores under `specs/<feature>/tdd/` (`test-list.md` behavior ids via
`TestListReader` row ids, `cycle-log.md` green sets via `CycleEvidence`,
`artifacts.json` gen registry via `ArtifactRegistry.loadAll`,
`ui-ledger.md` surface|kind|proven-by|state rows).

**Testing**: `package:test` (dart test); unit tests drive the checker core
directly (pure, temp-dir fixtures); CLI contract tests drive
`bin/zfa.dart` through the `runZfaSource` subprocess helper (the
`proof_command_test.dart` pattern) so exit codes are exercised exactly as
CI consumes them.

**Target Platform**: Linux/macOS/Windows (pure Dart, POSIX-normalized
paths).

**Project Type**: library/cli (zuraffa itself).

**Performance Goals**: default invocation spawns zero subprocesses; full
run over this repo's 161 specs < a few seconds (static file reads only).

**Constraints**: hard (from issue #1148) — new subcommand only; do not
change the existing receipt format, the existing `proof check`, the
existing `tdd verify`, or any generation verb; missing receipts are gaps,
not errors; one PR per issue.

**Scale/Scope**: 1 new checker module (~450 lines), 1 command class
(~120 lines), 2 test files; no schema changes; no generation-verb changes.

### Existing proof/verify commands (what this command READS, never rewrites)

| Command | Persistent artifact the chain reads |
| --- | --- |
| `zfa entity create` / `add-field` / `make` | `.zfa/receipts/<stamp>-<cmd>-<target>.json` (proof.v1) |
| `zfa state create` / `provider` / `mock` | `.zfa/receipts/<stable-name>.json` (proof.v1 + extras) |
| `zfa route create` | `.zfa/receipts/routes-<Entity>.json` (route table + digests) |
| `zfa route verify <Entity>` | `.zfa/receipts/routes-<Entity>-verify.json` (`verdict.ok`) |
| `zfa usecase create` | `.zfa/receipts/usecase-create-<entity>-<ts>.json` |
| `zfa usecase verify <Entity>` | no receipt — the gate (`UsecaseGate`) is re-run in-process by the chain |
| `zfa tdd gen/run` | `specs/<f>/tdd/artifacts.json` + `cycle-log.md` (red/green entries) |
| `zfa tdd plan` | `specs/<f>/tdd/test-list.md`, `ui-ledger.md` |
| `zfa proof check` (#807) | its `ProofChecker` engine is composed (not modified) for digest findings |

### Xray coverage format

`specs/<f>/tdd/ui-ledger.md` markdown table: `| surface | kind |
proven by | state |`. Kinds: `text`, `route`, `affordance`, `key`
(`UiSurfaceKind`). Traced-ness is recomputed: a row is traced iff at
least one prover id is in the feature's green-evidence set (the
"stored state is a cache, never the truth" rule).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- ✅ One PR per issue (only #1148's scope; the "make every verb emit
  receipts" work stays in its own tracking issue — gaps are reported, not
  forced).
- ✅ Errors are an API: every item ends with a `--> fix:` line; exit
  codes follow the ratified SPEC 917 golden table (0/1/2 semantics
  identical to the issue's requirement).
- ✅ Honest verdicts: gaps never paint missing proof as green; runtime is
  only claimed when actually exercised (`--run-tests`).
- ✅ No store is mutated — read-only auditor (FR-011).

## Project Structure

### Documentation (this feature)

```text
specs/1334-proof-check-end-to-end-validation/
├── plan.md              # This file
├── tasks.md             # /speckit-tasks output
└── tdd/
    ├── test-list.md     # /speckit-tdd-plan output
    ├── cycle-log.md     # red/green evidence (this session)
    └── verification.md  # /speckit-tdd-verify output
```

### Source Code (repository root)

```text
lib/src/
├── core/
│   └── proof/
│       ├── proof_checker.dart        # UNCHANGED (#807 engine, composed)
│       └── proof_chain_checker.dart  # NEW — the 6-check engine + verdict model
└── commands/
    └── proof_command.dart            # ProofChainCommand added; ProofCheckCommand untouched

test/
├── core/
│   └── proof_chain_checker_test.dart # NEW — unit tests (fixtures in temp dirs)
└── commands/
    └── proof_chain_command_test.dart # NEW — CLI contract tests (runZfaSource)
```

**Structure Decision**: the engine lives in `lib/src/core/proof/` next to
the #807 checker (same layer, same ownership); the command class is added
to the existing `proof_command.dart` so the `zfa proof` group stays one
registration point in `cli_runner.dart` (no runner change needed). Tests
mirror the existing `test/core/proof_checker_test.dart` +
`test/commands/proof_command_test.dart` split: unit tests for the pure
engine, subprocess tests for the exit-code protocol.

## Key Design Decisions

1. **`zfa proof chain`, not a modified `proof check`** — the hard
   constraint forbids touching #807's command; the new name is the
   issue's own vocabulary. The group help cross-references both.
2. **Compose `ProofChecker` for digest findings** — the #807 engine
   already implements digest drift/deleted/stale detection with
   expected/actual digests; composition (calling its `check()`) avoids
   re-implementation and cannot regress its behavior. Its findings map
   1:1 onto `receipt_digest` drift items.
3. **Drift vs gap severities** — drift (exit 1): what exists contradicts
   its proof. Gap (reported, exit 0-compatible): what should exist does
   not (behaviors without green evidence, routes/usecases never
   verified, untraced kinds, runtime not exercised). This is the literal
   hard constraint "missing receipts are reported as gaps, not errors"
   generalized to every check.
4. **In-process usecase gate** — `zfa usecase verify` persists no
   receipt; the chain re-runs `UsecaseGate` in-process (pure file
   parsing, no subprocess) so the check is honest today, and reads the
   create receipts for the entity set.
5. **Route verdicts read from the persisted receipt** — `routes-<Entity>-
   verify.json` is exactly the CI-readable latest verdict the route
   verify command writes; the chain trusts it (and reports staleness by
   `at` timestamp) rather than re-running route verification.
6. **`--run-tests` default off** — executing the generated suite is a
   CI posture (`zfa proof chain --run-tests && flutter test`); the
   default must stay fast and hermetic (NFR-001) and reports runtime as
   not-exercised info rather than claiming it.
7. **Injectable test runner** — the runner signature
   `Future<ProcessResult> Function(String, List<String>, {String? cwd})`
   defaults to `Process.run`; unit tests inject a fake so `--run-tests`
   is testable without spawning dart.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — no new packages, no schema forks, no new top-level
commands; the feature is one module + one subcommand.
