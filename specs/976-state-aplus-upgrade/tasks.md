# Tasks: state A+ upgrade (spec 976)

> Derived from `spec.md` (GitHub issue #976). RED → GREEN per behavior.

## Phase 1: property-based compile tier (RED first)

- [ ] T001 `test/plugins/state/state_property_compile_test.dart`: matrix
      {CRUD, getList+pagination, orchestrator, custom-usecase} generated
      into one shared sandbox (pubspec path-dep on the repo, pure-Dart
      flavor); `dart pub get --offline` + `dart analyze` (0 issues) +
      `dart run driver.dart` (round-trip copyWith/==/hashCode, pagination
      defaults, isLoading aggregation, hasError). Negative control:
      corrupted copyWith emission FAILS analyze (SC-1, AC-1).

## Phase 2: snapshot neutrality gate (RED first)

- [ ] T002 `test/plugins/state/state_snapshot_test.dart`: fixture matrix
      (6 configs × 2 flavors) byte-compared against committed goldens
      under `test/plugins/state/golden/`; `ZFA_STATE_UPDATE_GOLDENS=1`
      regenerates. Baseline captured pre-dedupe (SC-3, AC-3).

## Phase 3: --json verdict + receipt (RED first)

- [ ] T003 `test/plugins/state/state_create_json_receipt_test.dart`:
      envelope `{path, fields[], modes[], flavor, schema:1}` as last
      stdout line; receipt `.zfa/receipts/state-<entity>.json` (proof.v1,
      digest matches disk); `zfa proof check` ok:true; human output
      unchanged without `--json` (SC-2, AC-2).
- [ ] T004 `StateCreateCommand` (manual first-party subcommand via
      `manualSubcommandNames`), ReceiptStore optional `fileName`,
      envelope builder (fields parsed from emitted constructor — zero
      drift), receipt writer.

## Phase 4: drift gate (lands + passes)

- [ ] T005 `test/plugins/state/state_make_drift_test.dart`: byte-compare
      `zfa state create` vs `zfa make --state` for the same config across
      method-set matrix (SC-4, AC-4).

## Phase 5: outputSchema fix (RED first)

- [ ] T006 `test/plugins/state/state_output_schema_test.dart`:
      outputSchema describes `success`, `files: string[]`,
      `data.generatedFiles` items {path,type,action,content}; a
      schema-vs-actual shape validation of a real `execute()` result.
- [ ] T007 `create_state_capability.dart` outputSchema fix (order 5).

## Phase 6: dedupe (GREEN, byte-neutral)

- [ ] T008 Collapse the 6 derivation sites in `state_builder.dart` into
      one `_resolveEntityFieldNeeds` resolver; snapshot suite must stay
      green pre/post (order 3, AC-3).

## Phase 7: docs + verification

- [ ] T009 `openwiki/cli.md`: state row (--json verdict) + "State
      emission modes" section (entity/orchestrator/custom) (order 6).
- [ ] T010 `tdd/verification.md` (REAL evidence), cycle-log entries via
      the real `CycleLog.append` writer, `/speckit.tdd.verify` dispatch.
