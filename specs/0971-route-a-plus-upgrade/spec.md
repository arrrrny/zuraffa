# Spec 0971: route A+ upgrade — --json verdicts, routes receipt, zfa route verify, delete dead --methods flag

- **Issue**: https://github.com/arrrrny/zuraffa/issues/971
- **Parent**: #963 (UI coverage ledger) · **Proof lineage**: #842 (route-table tests), #807 (proof-carrying generation)
- **Branch**: `spec/0971-route-a-plus-upgrade`

## Mission

Make `route` an **A+ plugin** (currently A−, 4.45/5 — the strongest generator after tdd). It already self-proves via route-table tests (#842). Emit machine verdicts, persist the route table as a proof artifact, and delete the dead flag.

## Current state (what holds it back)

- **Agent contract 3/5:** No `--json` verdict, no receipts, no `--> fix:` lines. Dead `--methods` flag registered on the parent command whose `run()` is unreachable (`route_command.dart:9-15`, bug #856) — misleads `--help` readers.
- Success path prints emoji file lists; pure-Dart skip is a printed warning whose failure semantics live in a distant shared guard.

## Orders

1. **Delete the dead `--methods` option** from `RouteCommand` (`route_command.dart:9-15`). Bare `zfa route` already exits 64 correctly — keep that.
2. **`zfa route create --json`:** `{routes[], deepLinks, schemeRegistrations, routeTableTestPath, schema:1}`.
3. **Persist the route table:** `.zfa/receipts/routes-<entity>.json` via `ReceiptStore` — the #963 route-coverage ledger will consume this instead of re-parsing Dart. Include the route-table test path and its hash.
4. **`zfa route verify <Entity>`:** run the generated route-table test headlessly, emit a verdict receipt (declared vs resolved routes, deep-link patterns parsed), exit 0/1, `--> fix:` on mismatch.
5. **`--> fix:` lines** on every error path; the pure-Dart skip becomes a structured verdict (skip reason in the JSON envelope), not a bare warning.

## Acceptance — all must hold

- `zfa route --help` no longer advertises the dead `--methods` flag.
- `route create --json` envelope schema asserted by test.
- Fresh `route create` writes the routes receipt; `zfa proof check` green, red on hand-edited route file.
- `zfa route verify` exits 0 on a healthy table, 1 + `--> fix:` on a route whose builder is missing — both tested.

## Constraints

- Do NOT attempt DDA `@ZfaRoute` reconciliation here — that is a separate follow-up; note it in the final PR comment only.
- Do not change route emission semantics (name-identity replacement, self-healing — all working).
- Failing-first tests under `test/plugins/route/` (follow `bug_912_route_dry_run_route_table_test.dart` style).
- One PR per spec.
