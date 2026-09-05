# TDD Cycle Log — spec 0996-receipts-standalone-capabilities

Red → green → refactor evidence, from the REAL runs in this session.

## T001 RED — CapabilityInvocationWrapper auto-persists a receipt

Command:

    dart test test/core/plugin_system/capability_invocation_wrapper_test.dart \
             test/commands/capability_command_receipt_hook_test.dart

Result: `00:00 +0 -2: Some tests failed.` — both files fail to LOAD (the
red state for new code):

- `capability_invocation_wrapper_test.dart`: Error: Method not found:
  `CapabilityInvocationWrapper` (lib/src/core/plugin_system/capability_invocation_wrapper.dart
  does not exist).
- `capability_command_receipt_hook_test.dart`: Error: The getter `plugin`
  isn't defined for the type `GenerationReceipt` (likewise `capability`,
  `entity`) — the receipt schema fields from issue #996 are absent.

## T004/T005 RED — proof check `valid` verdict + receipt preflight gate

Command:

    dart test test/core/proof/proof_check_valid_test.dart \
             test/plugins/tdd/services/receipt_preflight_test.dart

Result: `00:00 +0 -2: Some tests failed.` — both files fail to LOAD:

- `proof_check_valid_test.dart`: Error: Method not found:
  `CapabilityInvocationWrapper`.
- `receipt_preflight_test.dart`: Error: Method not found: `ReceiptPreflight`
  (lib/src/plugins/tdd/services/receipt_preflight.dart does not exist).

## T002 RED — the 12-capability standalone receipt matrix

Command:

    dart test test/commands/capability_receipt_test.dart

Result: loading failure of the same symbols (wrapper + schema getters);
the matrix cannot run until the wrapper and receipt fields exist.

Red evidence summary: every new behavior in spec 0996 is pinned by a test
that fails before implementation, at the earliest possible phase (symbol
resolution — the new API surface does not exist).

## GREEN

### T001 GREEN — wrapper + hook

Command:

    dart test test/core/plugin_system/capability_invocation_wrapper_test.dart \
             test/commands/capability_command_receipt_hook_test.dart

Result: `00:00 +12: All tests passed.` (8 wrapper tests: key shape
`di-create-Product-<utc-stamp>.json`, no-receipt on failure / zero files /
skipped, best-effort warning, schema, exact run-hash derivation,
methodset/entity defaults, args delegation; 4 hook tests: receipt via
CapabilityCommand, parent-name pluginId fallback, failure protocol intact.)

### T002 GREEN — the 12-capability standalone receipt matrix

Command:

    dart test test/commands/capability_receipt_test.dart --preset=all

Result: `00:00 +12: All tests passed.` — di create, usecase create,
repository create, service create, datasource create, provider create
(service seeded first: the domain demands the interface), cache adapter
(entity seeded first: the registrar discovers real entities), state
create, observer create, sync enable, strategy create, shadcn `<layout>`.
Each run persists a receipt in `.zfa/receipts/` keyed
`<plugin>-<capability>-<entity>-<timestamp>.json` with the full
machine-readable schema, existing artifacts, 64-hex hash and
`receipt_version: 1`.

Fix surfaced by the matrix (pre-existing, on master): `zfa shadcn
<layout> <Entity>` crashed with `Could not find an option named
--dry-run / --layout / --methods` — ShadcnCommand never registered the
core params PluginManager.buildContext reads off argResults. Fixed by
registering them (mirrors MakeCommand._addCoreOptions).

### T003 GREEN — machine-readable receipt schema

Covered by the wrapper tests above (raw stored JSON assertions:
`plugin`, `capability`, `entity`, `receipt_version: 1`, `methodset`,
`hash` 64-hex, `files` with digests) and the hook test.

### T004 GREEN — zfa proof check validates the capability receipt

Command:

    dart test test/core/proof/proof_check_valid_test.dart

Result: `00:28 +2: All tests passed.` — real `zfa proof check
--format json` on a wrapper-persisted receipt: exit 0 with
`valid: true` (+ `ok: true`, 1 receipt, 1 artifact checked, 0 findings);
drift flips the verdict to `valid: false`, exit 1. `ProofReport.toJson`
now also speaks `valid` (issue #996 machine verdict).

### T005 GREEN — receipt preflight gate in zfa tdd verify

Command:

    dart test test/plugins/tdd/services/receipt_preflight_test.dart

Result: `00:00 +8: All tests passed.` (5 unit + 3 CLI): vacuous pass when
the project ships no receipts (backward compat), pass when the audited
subject is receipt-covered and valid, GATE FAILURE on `missing_receipt`
for an audited subject (exit 1, mutation audit never starts), GATE
FAILURE on drifted and on deleted receipted artifacts, and the CLI wires
the gate before the mutation audit in `zfa tdd verify`.


## REFACTOR + VERIFY (T006)

- `dart format .` — zero formatting diffs (`dart format --set-exit-if-changed .`
  → 0 changed).
- `dart analyze` — no new issues (all pre-existing errors live in
  `examples/`, which needs the Flutter SDK; 0 issues in every file this
  spec touched).
- `tools/run_tests_chunked.sh` chunk list, full FAST tier:
  **75/75 chunks passed, 0 chunk failures** (4 SKIP folders carry only
  slow-tier tests, by design).
- Test-pollution fix surfaced by the suite: two existing tests driving
  real generation through `CapabilityCommand` without a pinned project
  root (`test/plugins/mock/create_mock_capability_test.dart`,
  `test/integration/di_flag_parsing_test.dart`) wrote receipts into the
  repo working tree — now pinned to their temp fixtures.

## Verification (the REAL run, remediation pass 1 → 2)

Command:

    dart run bin/zfa.dart tdd verify --feature 0996-receipts-standalone-capabilities

Pass 1 (first honest run): `mutation: gate=fail_survived killed=37
survived=17 timed_out=0` — the audit wrote verification.md from the real
run and named every survivor (wrapper: snapshot-cap boundary/operator,
files sort, entity-fallback chain, methodset string split, backslash
normalization, binary probe, NamedCapability message; preflight: finding
detail strings, backslash normalization).

Remediation: 10 hardening tests added (8 wrapper + 2 preflight), each
pinning the exact contract the corresponding mutant breaks — binary
artifact → receipt with null snapshot; exactly-maxSnapshotBytes →
snapshot kept; multi-file receipts path-sorted with the hash re-derived
over the sorted order; empty-name entity fallback; result-payload name
fallback; comma-string methodset split; backslash path normalization;
NamedCapability message; the missing-receipt finding detail wording;
backslash audited-path normalization.

Pass 2 (the committed verdict):

    mutation: gate=pass killed=54 survived=0 timed_out=0
    mutation_was_run=true mutation_score=1.0000 restoration_verified=true

`tdd/verification.md` is generated FRESH from this run (preflight scope:
the three registered test files; subjects restored and hash-verified).

## Exit criteria demo (real CLI, this session)

- `zfa di create Product` in a temp project →
  `.zfa/receipts/di-create-Product-2026-09-04T20-08-20.748592Z.json`
- receipt document: `{plugin: di, capability: create, entity: Product,
  hash: <64-hex>, methodset: [], files: 5, receipt_version: 1}`
- `zfa proof check --format json` → exit 0,
  `{"schema":"proof.v1","ok":true,"valid":true,...,"findings":[]}`
- `zfa tdd verify` receipt preflight gate: engaged before the mutation
  audit (vacuous for receipt-less projects, hard failure on
  `missing_receipt` — pinned by the CLI tests above).
