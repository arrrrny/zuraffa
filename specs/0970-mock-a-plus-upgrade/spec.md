# Spec 0970: mock A+ upgrade — kill exit(64) lie, --json output, certification receipts, --certify gate, provider-builder test suite

- **Issue**: #970 (A+ UPGRADE)
- **Branch**: `spec/0970-mock-a-plus-upgrade`
- **Plugin**: mock (currently A−, 4.00/5)

## Mission

Make `mock` an **A+ plugin**. It is load-bearing for the entire TDD pipeline
(`zfa tdd make` defaults through it). Kill the remaining lying surfaces, make
"contract-conforming" a verifiable artifact, and test the untested builder.

## Current state (what holds it back)

- **Agent contract 3/5**: success output is emoji text (`✅ Mock data
  generation complete`, `mock_command.dart:122`); `--json` is input-only.
  `JsonMockCommand` calls bare `exit(64)` (`mock_command.dart:180`) — the
  in-process killer bug class #767 fixed elsewhere; kills MCP embedding. No
  receipts, no `--> fix:` lines.
- **Tests 4/5**: `mock_provider_builder_test.dart` has 2 tests for an 885-LOC
  builder — in a plugin whose whole promise is "contract-conforming" output.

## Requirements

- **FR-001 (T001)**: `JsonMockCommand` MUST NOT call bare `exit()`; a usage
  error sets `exitCode = 64` and returns, so an in-process host (MCP/embedded)
  survives. Regression test proves survival + exit code.
- **FR-002 (T002)**: `zfa mock create|data|json <Entity> --json` MUST print a
   machine envelope `{files[], actions, fixturesDir, certification, schema: 1}`
   (and nothing else) on success. Test asserts the exact schema.
- **FR-003 (T003)**: every generation MUST write the mock-certification receipt
  `.zfa/receipts/mock-<entity>.json` — methods implemented vs interface,
  fixture hashes, certification registry id (#832-style digest id), reusing the
  existing `ReceiptStore`/`proof.v1` contract. `zfa proof check` is green on
  fresh generation and red on hand-edit.
- **FR-004 (T004)**: `zfa mock create <Entity> --certify` runs a scoped
  `dart analyze` over the emitted mock files against their interface; drift →
  exit 1 with a `--> fix:` line naming the missing/incorrect members; a
  conforming mock passes.
- **FR-005 (T005)**: ≥8 behavioral tests for `mock_provider_builder.dart`
  (885 LOC): interface conformance, append-to-existing, edge-case types,
  negative cases — all asserting file content, not just existence.

## Acceptance criteria

- AC-1: `zfa mock json X` inside an in-process host sets exit codes without
  killing the process — regression test proves it.
- AC-2: `zfa mock create --json` returns the envelope; test asserts exact
  schema.
- AC-3: `.zfa/receipts/mock-<entity>.json` exists after create; `zfa proof
  check` green on fresh generation, red on hand-edit.
- AC-4: `--certify` fails (exit 1 + `--> fix:`) on a deliberately drifted
  mock; passes on a conforming one — both tested.
- AC-5: provider builder suite ≥8 tests, all asserting file content.

## Constraints

- Do not change what gets generated — only the contract around it.
- Every fix lands with a failing-first test under `test/plugins/mock/`.
- Validation: `dart analyze` on touched files + `dart test test/plugins/mock/`.
