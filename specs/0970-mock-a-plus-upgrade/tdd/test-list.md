# Test List: 0970-mock-a-plus-upgrade

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `zfa mock json` (no entity) inside an in-process host (MCP/embedded) sets exit code 64 and returns WITHOUT killing the host process. | AC-1 | GREEN |
| A2 | `zfa mock create <Entity> --json` prints the machine envelope with exactly the keys `{files, actions, fixturesDir, certification, schema}` and `schema == 1`. | AC-2 | GREEN |
| A3 | `zfa mock data <Entity> --json` and `zfa mock json <Entity> --json` print the same envelope schema. | AC-2 | GREEN |
| A4 | `.zfa/receipts/mock-<entity>.json` exists after create, records methods implemented vs interface, fixture hashes, and the certification registry id. | AC-3 | GREEN |
| A5 | `zfa proof check` is green right after a fresh mock generation and red after a hand-edit of a receipted mock artifact. | AC-3 | GREEN |
| A6 | `zfa mock create <Entity> --certify` fails with exit 1 and a `--> fix:` line naming the missing/incorrect members on a deliberately drifted mock. | AC-4 | GREEN |
| A7 | `zfa mock create <Entity> --certify` passes (exit 0) on a conforming mock. | AC-4 | GREEN |
| A8 | The provider builder suite has ≥8 behavioral tests, each asserting generated file CONTENT. | AC-5 | GREEN |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `JsonMockCommand`'s usage-error path sets `exitCode = 64` and returns (no `dart:io exit`). | FR-001 | GREEN |
| U2 | The `--json` envelope `files[]` entries carry `{path, action, type}`; `actions` carries per-action counts. | FR-002 | GREEN |
| U3 | The certification receipt is a `proof.v1` GenerationReceipt whose files carry sha256 digests of the final on-disk bytes. | FR-003 | GREEN |
| U4 | The certification registry id is derived from the certified surface (interface + method sets + fixture hashes). | FR-003 | GREEN |
| U5 | The certifier's structural check names interface members missing from the mock class. | FR-004 | GREEN |
| U6 | The certifier runs a scoped `dart analyze` over the emitted mock files (cwd = project root) and surfaces its errors with a `--> fix:` line. | FR-004 | GREEN |
| U7 | MockProviderBuilder: service-mode generation conforms to the declared interface methods (names + async/stream shapes) with canned mock values. | FR-005 | GREEN |
| U8 | MockProviderBuilder: entity-CRUD methods, append-to-existing, primitive/edge-case returns, and the negative (unknown method → ArgumentError; missing service → skip) all hold in emitted content. | FR-005 | GREEN |
