# Tasks — Spec 0973 repository A+ upgrade

TDD red → green → refactor → verify. All tests under `test/plugins/repository/`.

## T001 — Post-generation conformance gate (RED first)
- [ ] `RepositoryConformanceChecker` (in-process AST via FileParser.parseSource)
- [ ] Interface methods ↔ impl `@override` methods; verdict + failure list
- [ ] Failure prints `--> fix:` naming method + side, throws → CLI exit 1
- [ ] Delta scope for append flows (methods contributed this run); full scope for fresh pairs
- [ ] Fix pre-existing drift: synced `syncPending`/`pullRemote` missing `@override`
- Tests: `repository_conformance_test.dart`

## T002 — Repository contract manifest
- [ ] `repository-contract.v1` manifest at `.zfa/receipts/repository-<entity>.json`
- [ ] Method set + params/returns signatures, sha256-hashed (canonical JSON)
- [ ] Fresh generation writes the manifest (after the gate passes)
- [ ] `SourceInterfaceGuard` consumes manifest when fresh; falls back to parsing
- [ ] `zfa proof check` green on fresh, red on hand-edit (manifest_drift / manifest_corrupt)
- Tests: `repository_contract_manifest_test.dart`

## T003 — `--explain` / `--json` resolved-plan object
- [ ] `RepositoryEmissionPlanner`: pure config → emission plan (files, variant, triggered_by, warnings)
- [ ] `zfa make --explain` prints the resolved emission plan (text)
- [ ] `--json` flag + `--format json` emit the resolved-plan object
- [ ] Snapshot test for a cache+sync+datasource config
- Tests: `repository_emission_plan_test.dart`

## T004 — Variant content tests
- [ ] Synced variant content assertions (local-first reads, markPending, sync ops)
- [ ] Simple variant content assertions (direct `_dataSource` delegation)
- [ ] Append variant content assertions (existing methods preserved + new methods added)
- Tests: `repository_variant_content_test.dart`

## T005 — Refactor + verify
- [ ] `dart format .` → zero diffs; `dart analyze` clean
- [ ] `tools/run_tests_chunked.sh` → no new failures
- [ ] `/speckit.tdd.verify` → fresh `tdd/verification.md` from the real run
