# Test List: 0971-route-a-plus-upgrade

Format: `[status] BEHAVIOR-ID — one-line behavior (traces to order)`.
Statuses: PENDING → RED → GREEN → DONE. Tier: fast (unit).

## Outer acceptance behaviors

- [DONE] A1 [fast] `zfa route --help` no longer advertises the dead
  `--methods` flag (nor its `-m` abbreviation); the live subcommands
  (create/verify/custom/deep-link/shell) stay listed; bare `zfa route`
  still reports the missing subcommand (exit-64 contract pinned by
  `dead_positional_grammar_test`). (Order 1)
- [DONE] A2 [fast] `zfa route create <Entity> --json` emits one
  parseable envelope `{routes[], deepLinks, schemeRegistrations,
  routeTableTestPath, schema:1}` whose routes[] is the real declared
  table on disk. (Order 2)
- [DONE] A3 [fast] Fresh `route create` writes
  `.zfa/receipts/routes-Product.json` (proof.v1 + route-table data +
  route-table test path AND hash); the proof gate is green on a fresh
  create and red (modified) on a hand-edited route artifact. (Order 3)
- [DONE] A4 [fast] `zfa route verify <Entity>` exits 0 on a healthy
  table (+ passing headless run; also 0 when the runner is unavailable —
  static verdict decides) and exits 1 + `--> fix:` on a route whose
  builder is missing. (Order 4, acceptance)

## Inner unit behaviors

- [DONE] U1 [fast] Missing routes receipt → exit 1, fix line names
  `zfa route create <Entity>`. (Order 4/5)
- [DONE] U2 [fast] Failing headless route-table test run → exit 1, fix
  line points at `route_table_test.dart`. (Order 4)
- [DONE] U3 [fast] Declared route vanished from disk → exit 1, finding
  names the drifted route path. (Order 4)
- [DONE] U4 [fast] Hand-edited route-table test (hash drift) → exit 1,
  fix demands regeneration. (Order 3/4)
- [DONE] U5 [fast] Corrupt routes receipt JSON → exit 1 + fix line.
  (Order 5)
- [DONE] U6 [fast] `route create` with no entity → error + `--> fix:`
  + exit 64 (usage-error family). (Order 5)
- [DONE] U7 [fast] Pure-Dart package: `--json` → structured skip
  verdict (reason in the envelope, five contract keys present, exit 1);
  text mode → reason + fix line. (Order 5)
- [DONE] U8 [fast] Invalid `--scheme` → fail envelope with the fix;
  validation fires before any write. (Order 5)
- [DONE] U9 [fast] `route create --help` documents the `--json` verdict
  flag (the generic input-args JSON option is gone from this
  subcommand); `route verify --help` documents the `<Entity>`
  positional. (Order 2/4)
- [DONE] U10 [fast] Dry-run discipline: `--dry-run` writes neither files
  nor a receipt. (Order 3)
- [DONE] U11 [fast] Verify persists the verdict receipt
  `routes-<Entity>-verify.json` (proof.v1) and `--json` prints the
  schema-1 verdict envelope (verdict/entity/routes/resolvedRoutes/
  deepLinks/testRun/findings). (Order 4)
- [DONE] U12 [fast] Drift-mode regression: `zfa route verify` with no
  positional keeps the pre-existing drift semantics
  (`sc_001`/`sc_002`/`route_command_test` stay green). (Constraint:
  don't change existing contracts)
- [DONE] U13 [fast] Remediation (audit F1): a route module that
  appeared on disk after the receipt (stale ledger row) fails
  verification — exit 1, the finding names the unprovenanced disk
  route, `--> fix:` points at regeneration. Driven red-first. (Order 4)
