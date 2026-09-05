# Plan: 0970-mock-a-plus-upgrade

## Approach

The mock plugin's generation code (builders) is untouched; every change wraps
the contract AROUND generation: process-exit discipline, machine-readable
output, verifiable receipts, a certification gate, and the missing builder
tests.

## Architecture

```
lib/src/commands/mock_command.dart
  ├─ T001: JsonMockCommand usage error → exitCode = 64; return (slice #767 pattern)
  ├─ T002: --json output flag on create (new manual CreateMockCommand), data, json
  ├─ T003: MockCertificationService.record(...) after every generation
  └─ T004: --certify on create → MockCertifier.gate(...) → exit 1 + --> fix: on drift

lib/src/plugins/mock/services/mock_certification.dart   (new)
  ├─ MockCertification: registryId, interface, interfaceMethods,
  │   implementedMethods, missing, invented, conformance, fixture hashes
  ├─ certification recorder → ReceiptStore.saveAs('mock-<entity>.json', proof.v1)
  └─ MockCertifier gate: AST structural conformance + scoped dart analyze
      (injectable analyze runner for fast tests; real Process.run in the CLI)

lib/src/core/project/receipt_store.dart
  └─ + saveAs(fileName, receipt) — stable-name receipts (mock-<entity>.json)

test/plugins/mock/                        (all failing-first)
  ├─ mock_command_exit_test.dart           (T001 — in-process survival)
  ├─ mock_json_output_test.dart            (T002 — envelope exact schema)
  ├─ mock_certification_receipt_test.dart  (T003 — receipt + proof check)
  ├─ mock_certify_gate_test.dart           (T004 — drifted/conforming)
  └─ mock_provider_builder_suite_test.dart (T005 — ≥8 content tests)
```

## Decisions

- **create becomes a manual subcommand** (like `json`/`dependency` already
  are) so `--json` can be an output-mode flag instead of CapabilityCommand's
  input-JSON option. No existing caller uses input-`--json` on mock.
- **Receipt file name is stable per entity** (`mock-<entity>.json`): the
  latest generation supersedes (ProofChecker is latest-wins per artifact
  path), which is exactly the acceptance contract.
- **Certification registry id**: `mock-cert:<entity>@<digest8>` where the
  digest is over the certified surface (interface + method sets + fixture
  hashes) — deterministic, verifiable, in the #832 registry-id spirit.
- **The gate runs BOTH checks**: a deterministic AST structural comparison
  (interface methods vs emitted mock class methods — precise member names)
  and a scoped `dart analyze` subprocess over the emitted mock files (the
  authoritative compiler gate). Either failing → exit 1 + `--> fix:`.
- **Envelopes**: `files[]` = {path, action, type} per emitted file; `actions`
  = per-action counts; `fixturesDir` = directory of the emitted fixtures for
  the mode; `certification` = {registryId, interface, interfaceMethods,
  implementedMethods, conformance, receipt}; `schema: 1`.

## Test strategy (red → green per task)

| Task | Red evidence | Green proof |
| ---- | ------------ | ----------- |
| T001 | in-process run of `zfa mock json` (no args) kills the dart-test process (exit 64) | same run survives, exitCode == 64, usage line printed |
| T002 | `--json` flag does not exist / output not valid envelope JSON | exact key-set schema assertions on create/data/json |
| T003 | no `.zfa/receipts/mock-<entity>.json` after create | receipt exists, content asserted, ProofChecker green; hand-edit → red |
| T004 | `--certify` flag does not exist | drifted mock → exit 1 + `--> fix:` naming member; conforming → exit 0 |
| T005 | (new suite) | ≥8 behavioral tests asserting file content |

Final gate: `dart analyze` on touched files, `dart test test/plugins/mock/`,
chunked suite (no new failures), `dart format .` (zero diff), and
`zfa tdd verify --feature 0970-mock-a-plus-upgrade` producing
`tdd/verification.md` fresh from the real run.
