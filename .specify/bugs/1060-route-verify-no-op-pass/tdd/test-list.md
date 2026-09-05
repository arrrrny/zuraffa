# Test List — 1060-route-verify-no-op-pass

- **Source spec**: ../issue.md
- **TDD engine**: LLM-guided fallback (this bug dir is not under `specs/`,
  so `zfa tdd verify --feature` artifacts.json flow is unavailable; audit
  follows the extension's fallback contract).

## Outer-loop behaviors (acceptance — real fixtures, exit codes pinned)

| ID | AC | Subject | File | Status |
|----|-----|---------|------|--------|
| V1 | (a) | matching systems → verdict `match`, exit 0 | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V2 | (b) | path present in one system only → verdict `drift`, offending path named in `oneSided`, exit 1 | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V2b | (b) | symmetric: DDA-only path is drift too, source named | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V3 | (c) | missing DDA input → verdict `insufficient-input`, exit 2, missing input named | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V3b | (c) | missing CLI input → verdict `insufficient-input`, exit 2 | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V3c | (c) | no route inputs at all → verdict `insufficient-input`, exit 2 | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V4 | order 3 | `--strict` makes insufficient-input fail the run (exit 1) | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V5 | order 2 | verdicts and exit codes documented in help | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V6 | order 2 | insufficient-input distinguishable from match in text; one-sided path named in text | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| V7 | order 1 | CLI walker reads `*_shell.dart` branch routes (shell-only project reconciles → match) | `test/plugins/route/route_verify_verdict_test.dart` | GREEN |
| O1 | honesty | end-to-end `zfa route verify` on an empty project reports insufficient-input (exit 2), never a silent PASS (updated — old expectation WAS the bug) | `test/plugins/route/scenarios/sc_001_route_verify_test.dart` | GREEN |

## Inner-loop behaviors (unit — pre-existing, must stay green)

| ID | Concern | File | Status |
|----|---------|------|--------|
| U2.* | `RouteDriftDetector` pure API unchanged (overlap = finding; disjoint = zero findings) | `test/plugins/route/route_drift_detector_test.dart` | GREEN |
| O5 | #842 route-table self-test regression guard | `test/plugins/route/bug_912_route_dry_run_route_table_test.dart` | GREEN |
| sc_002 | drift discovery end-to-end + `--strict` exit 1 (existing contract preserved) | `test/plugins/route/scenarios/sc_002_route_verify_discovery_test.dart` | GREEN |
| U4.* | CLI surface: verify subcommand + flags + help advertisement | `test/cli/route_command_test.dart` | GREEN |

## Coverage trace

| Behavior | Traces to |
|----------|-----------|
| V1 | order 4(a), AC "all three verdict classes" |
| V2/V2b | order 4(b), order 1 tolerance clause, AC "detects real drift on mismatched fixture" |
| V3/V3b/V3c | order 4(c), order 1 tolerance clause, AC "insufficient-input (not PASS) with distinct exit code" |
| V4 | order 3 |
| V5 | order 2 "document in help output" |
| V6 | order 2 "distinguishable in both text and --json" |
| V7 | order 1 "wherever zfa route emits" |
| O1 | TRUTH-FLOOR: no silent PASS on empty input |
