# Spec 1110 — [ENGINE] Cert-gate: refuse run-engine on uncertified CORE entity

Issue: https://github.com/arrrrny/zuraffa/issues/1110
Branch: `spec/1110-cert-gate-engine`

## Problem

The cert/mocks + differential gate shipped (#1001, #1009), but the engine
pipeline doesn't actually block on a CORE entity being uncertified. A
CORE entity can still be wired into the engine slice with
`mock_certified: false` and the cycle will run:

- `zfa engine check` certified only STRUCTURALLY (method presence +
  seeded data file) — it never consulted `mock-cert.<Entity>.json`;
  after `zfa make engine Login` (whose chain does not certify) the check
  exited 0 with zero certification receipts on disk.
- `zfa tdd run-engine`'s spec-1001 preflight gate skipped entities
  without mock datasources, had NO freshness check (an entity changed
  after certification kept the stale green receipt), and wrote no
  refusal receipt.
- The pilot's failure-path double was a hand-roll
  (`_FailingAuthService`, 005-login-engine) instead of a framework
  feature.

## What was built

1. **Mock failure preset.** `zfa mock create Login --fail` (and
   `zfa make engine Login --fail`) emits a
   `<Entity>FailingMockProvider implements <Entity>DataSource` whose
   every method throws the framework's sealed failure type
   (`const ServerFailure(...)`, an `AppFailure` subtype; watch/watchList
   deliver it through `Stream.error`). The succeeding mock artifacts are
   still generated — the pair is the feature.
   `engine.receipt.json` records `failure_mode: failing | succeeding`.

2. **Certification registry check.**
   `lib/src/plugins/mock/certification/cert_registry.dart` — one place
   answering, per entity: is it referenced by the engine tree (mock
   datasource on disk, or a committed receipt)? does a parseable,
   all-satisfied `mock-cert.<Entity>.json` exist? is it FRESH (receipt
   mtime ≥ entity source mtime; a receipt older than the entity it
   certifies is stale)? Consumed by `EngineChecker.check` (step 6) and
   the `run-engine` preflight.

3. **Cert refusal is a receipt, not an exception.**
   `lib/src/engine/engine_gate_receipt.dart` writes
   `engine.gate.<Entity>.refused.json` (schema `engine.gate.v1`) with
   `{entity, reason, fix: "zfa mock create <Entity> --certify", refs,
   command, at}`. Two homes: `.zfa/` (engine check + make engine tail)
   and `specs/<feature>/tdd/` (run-engine preflight), where
   `zfa tdd status` renders the exact fix and exits non-zero.

4. **CERT-PLUGIN contract test.**
   `test/plugins/mock/cert_registry_test.dart` — structural +
   behavioral: register an entity, mark stale (entity mtime moved past
   the receipt), verify the gate blocks with the exact cert command.

5. **`zfa engine check` integration.** New finding code
   `uncertifiedCoreEntity`; check exits 1 with the refusal receipt path
   surfaced (text + `--format=json`), and the make-engine tail check
   inherits the same gate — no warning, no skip, no flag.

## Pre-existing bugs fixed on the critical path (honestly)

- `zfa mock create <Entity> --certify` never forwarded the flag into
  `CreateMockCapability` (the manual command bypassed the
  auto-registered CapabilityCommand), so the spec-1001 sandbox
  certification and its `mock-cert.<Entity>.json` receipt never ran via
  the CLI. The spec-1001 e2e integration test fails on master for
  exactly this reason. Fixed: the manual command forwards `certify`.
  When the sandbox cannot resolve the zuraffa package root (in-process
  hosts, projects without the dependency), the capability says so
  loudly and writes no receipt — the engine cert-gate refuses the
  entity downstream; the structural gate still governs the exit.
- The #970 structural gate's scoped `dart analyze` treated
  warning-only output as fatal (exit 2 on `dart analyze <files>`), so a
  clean mock with cosmetic warnings failed certification. Aligned to
  the errors-only policy the sandbox and the CI dart lane already use
  (`--no-fatal-warnings`).

## TDD artifacts

- `tdd/test-list.md` — the behavior list
- `tdd/verification.md` — the REAL verification record (gates, red →
  green evidence, actual command transcripts)
