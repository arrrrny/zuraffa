# Spec 1112 — [SKIN] zfa skin drive: VM-service tapAnchor seam, replaces synthetic clicks

Parent: #1015 (SKIN-CONTRACT) — depends on: #1111 (contract→ZuraffaApp), #1099 (zuraffa_ui)

## Problem

The pilot discovered synthetic clicks (cliclick, CGEvent, AX press) **never
reach the Flutter macOS view** — verified-correct coordinates produced no
hover, no press, no AX fallback path. **What works**:
`package:vm_service.evaluate` against the live app's library, finding the
`zfa:signin-guest` anchor by key, and invoking its real `onPressed` —
exercising the **genuine** engine flow (presenter → certified mock → push).
This spec makes that driver a framework feature.

## What to build

1. **`debugTapAnchor(String zfaKey)`** — kDebugMode-only top-level function.
   Signature: `Future<TapResult> debugTapAnchor(String zfaKey)` where
   `TapResult = found | disabled | notFound | error(String)`. Uses the
   element-walk pattern the pilot proved
   (`WidgetsBinding.instance.rootElement.visitChildElements(search)`).
2. **Generated per-view seam.** `zfa make --skin` emits, per declared anchor,
   a `debugTapLogOut()`, `debugTapGuest()`, etc. — one `debugTap<PascalAnchor>()`
   per `zfa:*` anchor — so the function lookup is just `debugTap<PascalAnchor>()`.
3. **`zfa skin drive` CLI.** `zfa skin drive --dart-uri=<vm-service-uri>
   --anchor=zfa:signin-guest`. Wraps `package:vm_service`, runs the evaluate,
   prints the `TapResult` JSON. Sub-agent friendly: same JSON regardless of
   host OS.
4. **`zfa simulate` integration.** Skin behaviors are driven through
   `debugTapAnchor` — no synthetic clicks, deterministic across
   macOS/Linux/iOS/Android/Windows.
5. **Widget test bridge.** A `zfaAnchorTapped(tester, zfaKey)` helper — the
   `package:zuraffa_test` surface — for widget tests that pump the same
   anchor-by-key lookup; `pumpAndSettle` is safe because the test-tree anchor
   can't reschedule itself.

## Success criteria

- `flutter run -t lib/main_skin.dart -d macos --debug` → grab VM URI →
  `zfa skin drive --dart-uri=... --anchor=zfa:signin-guest` prints
  `{"result":"found","tapped":true}`.
- Same command on a widget-test runner returns the same JSON shape.
- `zfa simulate` skin behaviors use `debugTapAnchor` exclusively; the pilot's
  cliclick code is deleted.

## Design (this PR's landing map — one PR to the framework repo)

The framework repo is pure Dart (Constitution VII: `lib/` never imports
Flutter), so the Flutter glue is EMITTED into target projects — the same
split spec 1102 used:

| Issue bullet | Landing site |
|---|---|
| `TapResult` + `debugTapAnchor` element walk | `lib/src/skin/tap_result.dart` (pure core) + the emitted kit's `debugTapAnchor` (Flutter glue, `SkinContractKitBuilder`) |
| Per-view seam | `ViewClassSpec.anchors` + `zfa make/view --skin --anchor <id>` emits the `anchorExists` row AND `debugTap<PascalAnchor>()` per anchor into the view file |
| `zfa skin drive` | `lib/src/skin/driver/vm_tap_driver.dart` + `SkinDriveCommand` (`zfa skin` group); `vm_service` promoted to a direct (pure-Dart) dependency |
| simulate/test-lane integration | the emitted `zfaAnchorTapped` bridge (test lane) + the CLI (live lane) are the ONLY tap paths; the skin lanes (`zfa tdd run-skin`, `zfa simulate`) drive anchors through them — no synthetic-click code exists anywhere in the repo (grep evidence) |
| widget test bridge | the builder emits `test/skin/zfa_anchor_test_bridge.dart` with `zfaAnchorTapped(WidgetTester, String)` — the target project's `package:zuraffa_test` surface (the bridge imports the kit through the app's `package:` URI; a relative import compiles a SECOND kit library — found and fixed during the scratch-app proof) |

The driver seam also gained `debugTapAnchorJson(String)` — a synchronous
string-returning evaluate facade — so `zfa skin drive` prints the TapResult
JSON verbatim, byte-identical on every host OS. The driver resumes a
paused-at-start isolate (`flutter test --start-paused` lane) and polls until
the anchor answers or the deadline elapses.

## Exit criteria (see tdd/verification.md for the REAL evidence)

- RED → GREEN with recorded evidence (tests written first, failed to load).
- The element walk, the disabled/notFound verdicts, the JSON contract, and
  the bridge proven on REAL Flutter 3.47.2 (scratch app, widget tests).
- `zfa skin drive` proven end-to-end against a LIVE Dart VM service AND a
  LIVE widget-test runner (flutter_tester) — same JSON shape on both.
