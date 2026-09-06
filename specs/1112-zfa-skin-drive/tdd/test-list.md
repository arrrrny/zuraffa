# TDD Test List — #1112 zfa skin drive (VM-service tapAnchor seam)

Every behavior below is written as a failing test FIRST (RED), then made to
pass (GREEN). One PR; branch `spec/1112-vm-service-anchor-seam`.

## RED evidence collected before implementation

| # | Defect / gap | Reproduction | Observed (RED) |
|---|--------------|--------------|----------------|
| R1 | No `TapResult` — the registry only answers `bool`, so a driver cannot distinguish found/disabled/notFound/error | `rg "TapResult" lib/src/skin/` | no matches; `ZfaAnchorRegistry.tap` returns `bool` |
| R2 | Emitted `debugTapAnchor` has the WRONG signature — `Future<bool>`, no element walk, no disabled/error verdicts | inspect `SkinContractKitBuilder` template | `Future<bool> debugTapAnchor(String zfaKey)` → `zfaAnchorRegistry.tap(zfaKey)` |
| R3 | No `zfa skin drive` command | `dart run bin/zfa.dart skin drive --dart-uri=x --anchor=y` | `Unknown subcommand` style usage output (skin has kit/verify only) |
| R4 | No per-view seam — `zfa make --skin` emits no `debugTap*()` functions and `make` has no `--skin-anchor` | `dart run bin/zfa.dart make --help` / inspect `ViewClassSpec` | no `skin-anchor` option; no seam emission in `view_class_builder.dart` |
| R5 | No widget-test bridge — `zfaAnchorTapped(tester, zfaKey)` does not exist anywhere | `rg "zfaAnchorTapped" lib test` | no matches |
| R6 | No simulate-side skin driving — `zfa skin sim` absent; skin behaviors have no deterministic anchor-protocol lane | `dart run bin/zfa.dart skin sim --help` | skin usage lists kit/verify only |

R-note (SC-1 honesty): the macOS live-app run (`flutter run -d macos` +
`zfa skin drive` against the real VM) is NOT executable in this Linux
container (no Flutter SDK, no macOS). The driver's wire-to-JSON plumbing is
proven for real against a fake `vm_service`-shaped client (T4.2–T4.8); the
emitted seam's live-tree half is pinned structurally (T3.*) and its verdict
mapping is proven for real in the pure registry (T2.*). verification.md
records this exactly.

## Behaviors

### T1 — TapResult pure core (`test/skin/tap_result_test.dart`)
- [ ] T1.1 `TapResult.found` → `{result: found, tapped: true}` JSON (the SC JSON shape)
- [ ] T1.2 `TapResult.disabled` / `.notFound` → `{result: ..., tapped: false}`
- [ ] T1.3 `TapResult.error('msg')` → `{result: error, tapped: false, message: msg}`
- [ ] T1.4 `TapResult.fromJson` round-trips all four verdicts (driver/sim receipts)
- [ ] T1.5 Equality: same verdict+message equal; different verdicts unequal

### T2 — Registry rich verdicts (`test/skin/anchors_tap_result_test.dart`)
- [ ] T2.1 `tapResult` on a registered+enabled anchor → `found`, handler invoked
- [ ] T2.2 `tapResult` on a registered-but-DISABLED anchor → `disabled`, handler NOT invoked
- [ ] T2.3 `tapResult` on an unknown anchor → `notFound`
- [ ] T2.4 `register` keeps the legacy 2-arg call enabled by default (non-breaking: existing `tap()` behavior unchanged)
- [ ] T2.5 `tap()` agrees with `tapResult()`: found ⇒ true; disabled/notFound ⇒ false

### T3 — Emitted kit seam (`test/skin/kit_debug_tap_anchor_test.dart`)
- [ ] T3.1 Emitted kit declares `Future<TapResult> debugTapAnchor(String zfaKey)` (issue signature)
- [ ] T3.2 Emitted kit is kDebugMode-only: release path returns an error TapResult, never taps
- [ ] T3.3 Emitted kit uses the pilot's element-walk (`renderViewElement!.visitChildElements`)
- [ ] T3.4 Walk verdicts: absent key → notFound; disabled/null-onPressed → disabled; enabled → invoke real onPressed → found; throw → error
- [ ] T3.5 Emitted `debugTapAnchorJson` produces the same JSON shape (sync String for VM evaluate)
- [ ] T3.6 Emitted ZfaButton registers with its live enabled state (contractEnabled flows into the registry)

### T4 — `zfa skin drive` (`test/commands/skin_drive_command_test.dart`)
- [ ] T4.1 Command registered as a `skin` subcommand named `drive` with `--dart-uri` + `--anchor`
- [ ] T4.2 found: fake VM evaluating to `{"result":"found","tapped":true}` → prints that JSON as final stdout line, exit 0
- [ ] T4.3 disabled / notFound → JSON printed, exit 1
- [ ] T4.4 error verdict → JSON printed, exit 2
- [ ] T4.5 Library auto-discovery: picks the isolate library ending `skin_contract_auditor.dart` without `--library`
- [ ] T4.6 Missing `--dart-uri` or `--anchor` → usage error, exit 64, no VM connection
- [ ] T4.7 Connection failure / malformed evaluate result → honest exit 2 with fix line, no fake pass
- [ ] T4.8 The evaluated expression is `debugTapAnchorJson('<anchor>')` against the resolved library (sub-agent-reproducible)
- [ ] T4.9 `package:vm_service` adapter compiles against the real client API (connector wiring pin)

### T5 — Per-view seam (`test/commands/make_skin_anchor_test.dart`)
- [ ] T5.1 `make` exposes a repeatable `--skin-anchor` option
- [ ] T5.2 `ViewClassSpec.skinAnchors` flows from the generator config (`--skin-anchor` → context data → spec)
- [ ] T5.3 Builder emits `Future<TapResult> debugTapGuest() => debugTapAnchor('zfa:signin-guest');` (naming: drop the first `signin-` segment, Pascal-case the rest)
- [ ] T5.4 `signin-log-out` → `debugTapLogOut()` (multi-segment Pascal)
- [ ] T5.5 No `--skin-anchor` → no seam functions emitted (byte-identical to pre-1112 --skin output apart from documented rows)

### T6 — Widget-test bridge (`test/skin/kit_test_bridge_test.dart`)
- [ ] T6.1 `zfa skin kit` emits the bridge at `test/skin/zfa_anchor_test_bridge.dart` (skip-if-exists, deterministic)
- [ ] T6.2 Bridge declares `Future<TapResult> zfaAnchorTapped(WidgetTester tester, String zfaKey)`
- [ ] T6.3 Bridge performs the same anchor-by-key lookup + `pumpAndSettle` after the tap (safe: no self-rescheduling)
- [ ] T6.4 Returned `TapResult.toJson()` matches the drive JSON shape exactly

### T7 — `zfa skin sim` (`test/commands/skin_sim_command_test.dart`)
- [ ] T7.1 Command registered as a `skin` subcommand named `sim` with `--manifest`
- [ ] T7.2 Manifest with `{anchors, taps}` drives the SAME registry protocol; one TapResult JSON line per tap
- [ ] T7.3 Declared expectations met → summary line `skin sim: ... found=<n> disabled=<n> notFound=<n> error=<n>`, exit 0
- [ ] T7.4 Expectation drift → drift lines + exit 1 (never a silent pass)
- [ ] T7.5 Malformed manifest → honest exit 2 with the offending path
