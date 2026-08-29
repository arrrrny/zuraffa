# Implementation Plan: X-Ray Visual Overlay with Bounding Boxes

**Branch**: `036-xray-visual-overlay` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/036-xray-visual-overlay/spec.md`

## Summary

This feature adds the pure-Dart half of the X-Ray Visual Overlay (v6 Track 4.2, issue #181). The pure-Dart half lives in this repository because the Zuraffa monorepo is split: the CLI, codegen, MCP server, and data models live here (`zuraffa`), while the Flutter rendering widgets (OverlayEntry painter, shake detector, neon brush) live in the separate `zuraffa_flutter` package. Without the pure-Dart data layer, the Flutter side has nothing to render against and no contract for state subscriptions, label formatting, or release-mode stripping.

The deliverable is therefore the **data model, serialization, registry, subscription API, label formatter, and release-mode strip** for the visual overlay. The Flutter painter and gesture detector are referenced from existing `zuraffa_flutter` exports (`XRayScope`, `XRayNode`) and are not regenerated here — they already exist.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`); Flutter 3.41+ toolchain installed at `/home/z/my-project/tools/flutter`.

**Primary Dependencies**: `args`, `code_builder`, `dart_style`, `analyzer` (codegen), `path`, `uuid`, `json_annotation`. No Flutter imports allowed in `lib/src/` per the project's hard rule (regression test `test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`).

**Storage**: `.dart_tool/zuraffa/xray.json` — existing persistent config flag file (written by `XrayCommand`, read by the Flutter overlay at boot). Already exists; this feature adds an `overlayActive` subkey for live activation state.

**Testing**: `package:test` (fast tier — `dart test` excludes `slow` tag). New tests live in `test/plugins/xray/` and `test/regression/` (one new regression for SC-004 release-mode strip).

**Target Platform**: Pure-Dart VM (Linux/macOS/Windows). The Flutter rendering targets iOS/Android/Web but lives outside this repo.

**Project Type**: Library + CLI + codegen + MCP server. The X-Ray overlay data layer is a new library under `lib/src/plugins/xray/`.

**Performance Goals**: Label formatting must be O(1) per node (no string concatenation in tight loops). Real-time state subscription must not rebuild unrelated bounding boxes (per-node `Stream`).

**Constraints**: Zero `package:flutter` imports in any new file under `lib/`. Zero X-Ray code paths in release builds (FR-007 / SC-004) — enforced via `kReleaseMode`-equivalent constant in pure Dart and via the `app_shell_builder` only emitting X-Ray wiring inside `if (kDebugMode) { ... }`.

**Scale/Scope**: ~6 new lib files, ~9 new test files, one CLI status subcommand flag, one codegen emit-site update.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The Zuraffa constitution (`.specify/memory/constitution.md`) is still in template form — `[PRINCIPLE_1_NAME]` placeholders, no ratified values. The default gates therefore apply:

1. **Library-First**: The new code lives as a library under `lib/src/plugins/xray/` with a barrel export — independently importable and testable.
2. **CLI Interface**: `zfa xray enable/disable/status` already exists; this feature extends `status` with a `--json` flag for machine-readable state (consumed by the overlay UI and by CI).
3. **Test-First (NON-NEGOTIABLE)**: Every behavior in `tdd/test-list.md` has a failing test BEFORE its implementation. Red evidence is recorded in `tdd/red/` and cited in `tdd/verification.md`.
4. **Integration Testing**: New contract tests for the JSON shape returned by `XRayOverlayState.toJson()` so the MCP bridge (Track 4.4) can consume it without surprises.
5. **Simplicity**: No new dependencies added. Pure-Dart data classes + a `Stream`-based registry. No reflection, no mirrors.

All gates pass at design time.

## Project Structure

### Documentation (this feature)

```text
specs/036-xray-visual-overlay/
├── spec.md              (input — already exists)
├── plan.md              (this file)
├── tasks.md             (MVP-first task list)
├── checklists/
│   └── requirements.md  (already exists, ✅ ALL PASS)
└── tdd/
    ├── test-list.md     (TDD plan — behaviors + tests)
    ├── red/             (red evidence per behavior)
    │   ├── 01-node-model.md
    │   ├── 02-state-summary.md
    │   ├── 03-box-label-format.md
    │   ├── 04-bounding-box-color.md
    │   ├── 05-overlay-registry.md
    │   ├── 06-detail-panel-json.md
    │   ├── 07-shake-detector-shim.md
    │   └── 08-release-mode-strip.md
    └── verification.md   (green state + SC mapping)
```

### Source code

```text
lib/src/plugins/xray/
├── xray_deck_barrel_writer.dart     (existing — Track 4.3 work, untouched)
├── xray_mock_scaffolder.dart         (existing — Track 4.3 work, untouched)
├── xray_node.dart                   (NEW — pure-Dart XRayNode data model)
├── xray_state_summary.dart          (NEW — SignalSlice state summary)
├── xray_box_label.dart              (NEW — inline label formatter)
├── xray_box_color.dart              (NEW — per-view-type neon color)
├── xray_bounding_box.dart           (NEW — rect + label + color)
├── xray_detail_panel.dart          (NEW — full state JSON dump)
├── xray_overlay_state.dart         (NEW — registry + subscription API + release guard)
├── xray_shake_detector.dart         (NEW — abstract interface + no-op default)
└── xray_overlay.dart               (NEW — barrel export)

lib/src/core/
└── xray_config.dart                 (EXTENDED — add isReleaseMode + shouldXRayBeActive)

lib/src/commands/
└── xray_command.dart                (EXTENDED — add --json flag to status, release-mode guard)

lib/src/plugins/app_shell/builders/
└── app_shell_builder.dart           (EXTENDED — emit XRayOverlayState.activate() in kDebugMode)
```

### Tests

```text
test/plugins/xray/
├── xray_node_test.dart              (NEW)
├── xray_state_summary_test.dart     (NEW)
├── xray_box_label_test.dart         (NEW)
├── xray_box_color_test.dart         (NEW)
├── xray_bounding_box_test.dart      (NEW)
├── xray_detail_panel_test.dart      (NEW)
├── xray_overlay_state_test.dart     (NEW)
└── xray_shake_detector_test.dart     (NEW)

test/regression/
└── issue_181_xray_release_mode_strip_test.dart  (NEW — SC-004 regression)

test/commands/
└── xray_status_json_test.dart       (NEW — CLI --json flag)
```

## Goals & Strategy

### Primary goal

Add the pure-Dart data layer for the X-Ray Visual Overlay such that the `zuraffa_flutter` package can render bounding boxes against a stable contract: a `List<XRayBoundingBox>` produced by `XRayOverlayState`, label-formatted by `XRayBoxLabel.format()`, color-coded by `XRayBoxColor.forViewType(viewType)`, with real-time subscription via `XRayOverlayState.changes`, detail-panel serialization via `XRayDetailPanel.fromNode(...)`, and a hard release-mode strip that makes all of these no-ops in `dart.vm.product`.

### Non-goals

- Implementing the Flutter painter (lives in `zuraffa_flutter`).
- Implementing the real shake-detector platform channel (lives in `zuraffa_flutter`; we only define the abstract interface so the Flutter side can plug in).
- Changing the MCP server contract (Track 4.4 — separate spec 035).
- Implementing the Control Deck (Track 4.3 — separate spec 034).

### Strategy

1. **MVP slice (P1)**: `XRayNode`, `XRayOverlayState` with `activate/deactivate/register/unregister/changes`, release-mode strip via `bool.fromEnvironment('dart.vm.product')`. Shake-detector interface + no-op default. This satisfies SC-001 + SC-004.
2. **Label slice (P2)**: `XRayStateSummary`, `XRayBoxLabel`, `XRayBoxColor`, `XRayBoundingBox`. This satisfies SC-002.
3. **Inspect slice (P2)**: `XRayDetailPanel` with `fullStateJson` and `fromNode`. This satisfies SC-003 (data side; the <200ms panel-open is a Flutter concern but the data fetch is O(1) lookup).
4. **CLI slice (P3)**: `zfa xray status --json` for machine-readable output.
5. **Codegen slice**: emit `XRayOverlayState.activate()` inside `if (kDebugMode) { ... }` in the generated `main.dart`.

### Architecture

The data layer is intentionally boring: immutable data classes (with `const` constructors where possible), one mutable registry (`XRayOverlayState`), one abstract platform interface (`XRayShakeDetector`), and a single release-mode constant. The real-time subscription is a `Stream<List<XRayBoundingBox>>` built on a `StreamController.broadcast()` so the Flutter overlay can listen without affecting the registry.

The release-mode strip is the only non-trivial design choice. Pure Dart has `bool.fromEnvironment('dart.vm.product')` (compiled-in constant), which the codegen wraps in a guard:

```dart
// In lib/src/plugins/xray/xray_overlay_state.dart
final bool _kReleaseMode = bool.fromEnvironment('dart.vm.product');
```

Every public method on `XRayOverlayState` early-returns when `_kReleaseMode` is `true`. The codegen additionally emits `if (kDebugMode) { ... }` around the activation call in `main.dart` so the Flutter tree-shaker removes the entire code path. The regression test at `test/regression/issue_181_xray_release_mode_strip_test.dart` verifies this two-layer strip: (a) the pure-Dart `_kReleaseMode` guard, and (b) the codegen's `kDebugMode` wrap.

### Risks

- **Risk**: `bool.fromEnvironment` is not testable at runtime (it's a compile-time constant). **Mitigation**: the `XRayOverlayState` accepts an optional `isReleaseMode` constructor param (defaults to the constant) so tests can pass `true` and verify the no-op path.
- **Risk**: the Flutter side (`zuraffa_flutter`) has not yet shipped the painter — we're defining a contract against an unshipped dependency. **Mitigation**: the contract is intentionally minimal (rect + label + color + Stream); any reasonable painter can consume it.
- **Risk**: codegen updates to `app_shell_builder.dart` could break existing app-shell tests. **Mitigation**: the new emit only fires when `xray: true` is passed (same gate as existing X-Ray wiring); existing tests with `xray: false` (default) are unaffected.

## Changes

*Reference for tracking — full task list lives in [tasks.md](./tasks.md).*

### Phase 1: Setup (shared infrastructure)
- Create the new directory layout under `lib/src/plugins/xray/`.
- Add barrel export `lib/src/plugins/xray/xray_overlay.dart`.

### Phase 2: Core (P1)
- Implement `XRayNode` (immutable data class with `toJson`/`fromJson`).
- Implement `XRayOverlayState` (registry + subscription + release guard).
- Implement `XRayShakeDetector` abstract interface + no-op default.

### Phase 3: Labels & Boxes (P2)
- Implement `XRayStateSummary` (with `fromSignalSlice<T>` factory).
- Implement `XRayBoxLabel` (formats the inline label string).
- Implement `XRayBoxColor` (per-view-type neon palette).
- Implement `XRayBoundingBox` (rect + label + color).

### Phase 4: Detail Panel (P2)
- Implement `XRayDetailPanel` (full state JSON dump).

### Phase 5: CLI + Codegen Wiring (P3)
- Extend `zfa xray status` with `--json` flag.
- Extend `app_shell_builder.dart` to emit `XRayOverlayState.activate()` in `kDebugMode`.

### Phase 6: Release-Mode Strip Regression
- Add `test/regression/issue_181_xray_release_mode_strip_test.dart`.

### Phase 7: Export & Verify
- Add `export 'src/plugins/xray/xray_overlay.dart';` to the public barrel (if applicable).
- Run `dart analyze && dart test` (relevant subset).
- Write `tdd/verification.md`.

## Sketch

### XRayNode (immutable)

```dart
class XRayNode {
  final String id;            // e.g. "ProfileViewNode.editProfileButton"
  final String viewType;     // e.g. "ProfileView"
  final bool enabled;
  final String? boundAction; // e.g. "onEditTapped"
  final XRayStateSummary stateSummary;
  final List<XRayNode> children;
  const XRayNode({
    required this.id,
    required this.viewType,
    required this.enabled,
    required this.stateSummary,
    this.boundAction,
    this.children = const [],
  });
  Map<String, dynamic> toJson();
  factory XRayNode.fromJson(Map<String, dynamic> json);
}
```

### XRayOverlayState (mutable registry + Stream + release guard)

```dart
class XRayOverlayState {
  XRayOverlayState({bool? isReleaseMode})
    : _isReleaseMode = isReleaseMode ?? _kReleaseMode;

  static const _kReleaseMode = bool.fromEnvironment('dart.vm.product');
  final bool _isReleaseMode;

  bool get isActive;
  List<XRayNode> get nodes;       // snapshot
  Stream<List<XRayBoundingBox>> get changes;

  void activate();               // no-op in release
  void deactivate();
  void register(XRayNode node);
  void unregister(String id);
  XRayDetailPanel? inspect(String nodeId);
  Map<String, dynamic> toJson(); // for MCP bridge
}
```

### XRayShakeDetector (abstract)

```dart
abstract class XRayShakeDetector {
  Stream<void> get shakes;
  static XRayShakeDetector instance = _NoOpShakeDetector();
}
class _NoOpShakeDetector implements XRayShakeDetector {
  const _NoOpShakeDetector();
  @override
  Stream<void> get shakes => const Stream<void>.empty();
}
```

### Release-mode strip

```dart
// lib/src/core/xray_config.dart (extended)
const bool kXrayReleaseMode = bool.fromEnvironment('dart.vm.product');
bool shouldXRayBeActiveInCurrentBuild() => !kXrayReleaseMode;
```

The codegen emits, in `main.dart`:

```dart
if (kDebugMode) {
  await XRayOverlayState.instance.activate();
}
```

## Deferred / Future Work

- **Real shake detector**: Flutter platform channel binding for accelerometer shake detection — lives in `zuraffa_flutter`.
- **Painter**: neon box painting, dimmed background, touch-passthrough hit-test — lives in `zuraffa_flutter`.
- **MCP integration**: `GET /xray/tree` will be wired to `XRayOverlayState.toJson()` in Track 4.4 (spec 035).
- **Control Deck integration**: tapping a deck button will call `XRayOverlayState.register(XRayNode(...))` — wired in Track 4.3 (spec 034).
