# Bug Spec: TDD Plugin --json Verdict Envelope + Receipts

## Overview
The TDD plugin's CLI surface is hostile to agents: only 2 of 25 commands emit JSON, and only 1 of the generation commands writes provenance receipts. This violates VISION §5 (--json everywhere, agent-dialect) and §3 (manifest is a treaty). The fix establishes a uniform versioned `verdict.v1` envelope on all leaf commands and wires receipts into the generation trio.

## User Scenarios

### Scenario 1: CI agent runs any TDD command with --json
- Given a CI pipeline drives `zfa tdd <verb> <args> --json`
- When the verb completes
- Then the **last** stdout line is a valid `{"schema": "verdict.v1", ...}` JSON envelope
- And the exit code follows the protocol: 0=pass, 1=stopped/red, 2=invalid-grammar, 3=manifest-drift, 4=state-conflict

### Scenario 2: Default text output preserved
- Given an operator runs `zfa tdd <verb> <args>` (no --json)
- When the verb completes
- Then stdout is the existing human-readable `key=value` summary
- And no JSON appears in stdout (to keep scripts that grep for text unaffected)

### Scenario 3: gen/reset migrate to --json-gated
- Given `gen` and `reset` currently emit JSON unconditionally
- When the fix lands
- Then those two commands emit JSON only when `--json` is passed
- And emit the existing `key=value` summary otherwise

### Scenario 4: Receipts on gen/make/view
- Given `gen` writes artifacts, `make` wires subjects, and `view` scaffolds widget subjects
- When any of these commands completes successfully
- Then a #807 receipt entry is written to `.zfa/receipts/` for each created file
- And `zfa proof check` recognizes the new receipts

## Functional Requirements

- **FR-1**: A shared `VerdictEnvelope` model in `lib/src/plugins/tdd/models/verdict_envelope.dart` with the fields: `schema` ("verdict.v1"), `command`, `feature?`, `verdict` (pass|fail|stopped|error), `details` (command-specific key/value map), `timestamp` (ISO 8601)
- **FR-2**: All 22 leaf TDD commands register `argParser.addFlag('json', negatable: false)` and route their existing summary through the envelope when `--json` is set
- **FR-3**: `gen_command._printBatchVerdict` and `reset_command._printVerdict` are gated on `--json`
- **FR-4**: A `_printVerdict` helper is extracted (or duplicated) per command that captures the command's existing summary fields into the envelope's `details`
- **FR-5**: `gen`, `make`, `view` write a #807 receipt (via `NuanceReceipts.record` or `ReceiptStore`) for each artifact file created
- **FR-6**: A pure function `VerdictEnvelope.emit(command, verdict, details)` is added and unit-tested
- **FR-7**: A unit test verifies the `verdict.v1` schema is stable across all 22 commands

## Out of Scope
- Issue #965 i18n-keyed widget contracts (slang test shell)
- Streaming JSON via `--stream` (VISION §5 aspirational, separate spec)
- Schema migration to `verdict.v2` (future)

## Success Criteria
- `dart test test/plugins/tdd/verdict_envelope_test.dart` passes
- `dart test test/plugins/tdd/json_flag_test.dart` passes
- `dart test test/plugins/tdd/receipts_on_gen_make_view_test.dart` passes
- Manual smoke: `zfa tdd plan --json | jq .schema` returns `"verdict.v1"` for every leaf verb
