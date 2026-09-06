# Feature Specification: `zfa skin drive` — VM-service tapAnchor seam, replaces synthetic clicks

**Feature Branch**: `spec/1112-vm-service-anchor-seam`

**Created**: 2026-09-07

**Status**: Implemented

**Template Version**: `zuraffa-1.0`

**Input**: https://github.com/arrrrny/zuraffa/issues/1112 — [SKIN] zfa skin drive: VM-service tapAnchor seam, replaces synthetic clicks (parent #1015; depends on #1099 zuraffa_ui, #1111 contract→ZuraffaApp)

## Context

The login-skin pilot (006) proved that synthetic clicks (cliclick, CGEvent, AX
press) NEVER reach the Flutter macOS view: verified-correct coordinates produced
no hover, no press, and no AX fallback path. The pilot ALSO proved what works:
`package:vm_service.evaluate` against the live debug app — finding the
`zfa:signin-guest` anchor by key and invoking its REAL `onPressed`, exercising
the genuine engine flow (presenter → certified mock → push). That driver was
ad-hoc (`tool/drive_guest.dart` + `debugTapGuest()` in the pilot's
`lib/main_skin.dart`). This feature makes the driver a FRAMEWORK feature.

In this repository the seam follows Constitution VII: `lib/` never imports
Flutter. The pure protocol (anchor vocabulary, registry, `TapResult`) lives in
`lib/src/skin/anchors.dart` (exported through `package:zuraffa/skin.dart`); the
Flutter half (the element-walking `debugTapAnchor`) is EMITTED into the target
app by the skin kit — the same emission path `zfa skin kit` already uses for
the auditor glue.

## Requirements (from the issue)

- FR-1 `debugTapAnchor(String zfaKey)` — kDebugMode-only top-level function
  with signature `Future<TapResult> debugTapAnchor(String zfaKey)` where
  `TapResult = found | disabled | notFound | error(String)`. Uses the pilot's
  proven element-walk pattern (`WidgetsBinding.instance.renderViewElement!
  .visitChildElements(search)`). Pure Dart `TapResult` carries a JSON contract:
  `{"result":"found","tapped":true}` (+ `message` for `error`).
- FR-2 Generated per-view seam — `zfa make --skin` (with `--skin-anchor`)
  emits, for each ZfaButton-anchored view, one `debugTap<PascalAnchor>()`
  function per `zfa:signin-*` anchor (`debugTapGuest()`, `debugTapLogOut()`,
  ...), so the function lookup is just `debugTap<PascalAnchor>()`.
- FR-3 `zfa skin drive` CLI — `zfa skin drive --dart-uri=<vm-service-uri>
  --anchor=zfa:signin-guest` wraps `package:vm_service`, evaluates the emitted
  seam on the app's main isolate, and prints the `TapResult` JSON. Sub-agent
  friendly: the same JSON on every host OS; exit 0 tapped / 1 not tapped
  (disabled, notFound) / 2 error (connection, evaluation, malformed).
- FR-4 `zfa simulate` integration — skin behaviors are driven through the
  anchor-tap protocol EXCLUSIVELY, with zero synthetic clicks, deterministic
  across macOS/Linux/iOS/Android/Windows: `zfa skin sim` replays a committed
  manifest through the same registry protocol `debugTapAnchor` uses (the
  issue names `zfa skin sim` as the simulate-side surface), emitting the same
  TapResult JSON lines and enforcing declared expectations (drift = exit 1).
- FR-5 Widget test bridge — a `zfaAnchorTapped(tester, zfaKey)` helper
  (emitted test-support library) for widget tests that performs the same
  anchor-by-key lookup; `pumpAndSettle` is safe because the test-tree anchor
  cannot reschedule itself (subscribe-don't-poll, pilot lesson 5).
- FR-6 The pilot's cliclick code is deleted — this repository contains zero
  synthetic-click driving; the driver NEVER synthesizes OS input events.

## Success criteria

1. On a macOS host: `flutter run -t lib/main_skin.dart -d macos --debug` →
   grab the VM URI → `zfa skin drive --dart-uri=... --anchor=zfa:signin-guest`
   prints `{"result":"found","tapped":true}`. (Requires a macOS host with the
   pilot workspace — NOT executable in this Linux CI container; the JSON
   contract and the driver plumbing are proven by the fake-VM test suite, see
   `tdd/test-list.md` R-note.)
2. The same JSON shape from a widget-test runner via `zfaAnchorTapped` —
   the bridge returns `TapResult` whose `toJson()` is the identical shape.
3. Skin behaviors are driven through `debugTapAnchor` exclusively; the pilot's
   cliclick code is deleted (verified: zero `cliclick`/`CGEvent`/AX-press
   references in the tree; the driver path only ever invokes the real
   `onPressed` through the anchor protocol).

## Stakeholders

- Sub-agents / CI: consume `zfa skin drive` JSON (host-OS independent).
- Skin authors: `--skin-anchor` declarations + per-view seam functions.
- Framework maintainers: one protocol (anchors.dart) for kit, CLI, sim, tests.
