# Tasks: 0971-route-a-plus-upgrade

- [x] T001 — Delete the dead `--methods` option from `RouteCommand`; `zfa route --help` no longer advertises it; bare `zfa route` keeps exit 64. (test: `spec_971_t001_dead_methods_flag_test.dart`)
- [x] T002 — `zfa route create --json` envelope `{routes[], deepLinks, schemeRegistrations, routeTableTestPath, schema:1}` via a manual `RouteCreateCommand` (the schema-generated `CapabilityCommand`'s `--json` is an INPUT flag — replaced, not overloaded). (test: `spec_971_t002_create_json_envelope_test.dart`)
- [x] T003 — Persist `.zfa/receipts/routes-<Entity>.json` via `ReceiptStore.saveNamed` (proof.v1 digests + route-table-as-data for the #963 ledger; route-table test path + hash); `zfa proof check` green on fresh create, red on hand-edit. (test: `spec_971_t003_routes_receipt_test.dart`)
- [x] T004 — `zfa route verify <Entity>`: receipt-driven static verdict (declared vs resolved, GoRoute builder presence, deep-link patterns, proof-artifact digest) + headless route-table-test run (injectable runner) + verdict receipt + exit 0/1 + `--> fix:`. (test: `spec_971_t004_route_verify_test.dart`)
- [x] T005 — `--> fix:` lines on every error path (no entity, pure-Dart skip, invalid scheme, corrupt/missing receipt, all verify findings); pure-Dart skip becomes a structured verdict (skip reason in the JSON envelope); dry-run writes no receipt. (test: `spec_971_t005_fix_lines_test.dart`)
- [x] T006 — Refactor + verify: `dart analyze` (0 new issues), chunked fast suite 74/74 chunks green (route chunk 3× flake-free), `dart format .` zero diffs.
- [x] T007 — `/speckit.tdd.verify` dispatched; `tdd/verification.md` generated from the real runs of this session.
- [x] R1 (audit remediation, /speckit.tdd.verify pass-1 finding F1) — Reverse drift direction: a route module added after the receipt (stale ledger row) fails verification with a `--> fix:` line (driven red-first). (test: `spec_971_f1_reverse_drift_test.dart`)
