# Test List — route-dual-system-unreconciled

- **Source spec**: ../spec.md
- **TDD engine**: LLM-guided fallback (this bug dir is not under `specs/`,
  so `zfa tdd plan` was bypassed; behavior derivation follows the same
  contract).

## Outer-loop behaviors (acceptance — drive via real CLI)

| ID | AC | Subject | File | Status |
|----|-----|---------|------|--------|
| O1 | AC1 | `zfa route verify` exits non-zero on a project with conflicting CLI+DDA routes, and reports each drift with its source file | `test/plugins/route/scenarios/sc_001_route_verify_drift_test.dart` | PENDING |
| O2 | AC2 | `zfa route verify --json` emits a stable `route-table.json` containing every route from both systems | `test/plugins/route/scenarios/sc_002_route_verify_json_test.dart` | PENDING |
| O3 | AC3 | `zfa route verify --plain` output is byte-identical across runs (no emoji, no color) | `test/plugins/route/scenarios/sc_003_route_verify_plain_test.dart` | PENDING |
| O4 | AC4 | Drift lint warns on a project that has `*_routes.dart` but no `@ZfaRoute`, and `--strict` promotes the warning to a non-zero exit | `test/plugins/route/scenarios/sc_004_drift_lint_test.dart` | PENDING |
| O5 | AC5 | The pre-existing route-table self-test (issue #842) still passes — we do not regress probe-on-disk | `test/plugins/route/bug_912_route_dry_run_route_table_test.dart` (existing) | GREEN — must stay GREEN |

## Inner-loop behaviors (unit — pin the building blocks)

| ID | Concern | Subject | File | Status |
|----|---------|---------|------|--------|
| U1 | RouteTable DTO has union-of-routes semantics and stable JSON encoding | `RouteTable` from CLI + DDA inputs | `test/plugins/route/route_table_test.dart` | PENDING |
| U2 | Drift detector returns one finding per overlapping path, naming both source files | `RouteDriftDetector` | `test/plugins/route/route_drift_detector_test.dart` | PENDING |
| U3 | Output formatter has a plain mode that strips emoji + ANSI | `OutputFormatter.plain` | `test/cli/standard/output_format_plain_test.dart` | PENDING |
| U4 | CLI route command surface: `verify` is reachable as a subcommand with `--json`/`--plain`/`--strict`/`--out` flags | `RouteCommand` argument grammar | `test/cli/route_command_test.dart` | PENDING |

## Coverage trace

| Behavior | Traces to |
|----------|-----------|
| O1, O2, O3, O4 | AC1–AC4 in spec.md |
| O5 | AC5 (regression guard) |
| U1, U2 | Implementation concerns in spec.md "Files Likely To Change" |
| U3 | `lib/src/cli/standard/output_format.dart` plain mode |
| U4 | `lib/src/commands/route_command.dart` subcommand grammar |

## Test ordering (deterministic red-green-refactor)

1. U4 (CLI surface) — RED first; pins the public contract.
2. U1 (RouteTable DTO) — RED; needed before any detector test.
3. U2 (DriftDetector) — RED; needs U1's DTO.
4. U3 (plain output) — RED; independent.
5. O1, O2, O3, O4 (acceptance) — RED; these are the user-facing proof.
6. O5 — re-run last to confirm no regression.

`tdd/run-state.json` will track which behavior is next.
