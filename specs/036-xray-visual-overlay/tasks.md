# Tasks: X-Ray Visual Overlay with Bounding Boxes

**Input**: Design documents from `specs/036-xray-visual-overlay/`

**Prerequisites**: plan.md (required), spec.md (required for user stories).

**Tests**: Tasks marked with `[T]` are behavior-driving test tasks written FIRST (TDD red), then made green by their pairing implementation task. Tests are MANDATORY per the spec's SC-001..004.

**Organization**: Tasks are grouped by user story from `spec.md`. Each user story can be implemented + tested independently and shipped as an MVP increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story US1=Activate (P1), US2=Inspect (P2), US3=Labels (P2), US4=CLI (P3)
- Exact file paths are in descriptions

## Phase 1: Setup (Shared Infrastructure)

- [ ] T01 [P?] US1 Create directory `lib/src/plugins/xray/` if missing (already exists with two files — no action needed beyond confirming).
- [ ] T02 [P?] US1 Create barrel `lib/src/plugins/xray/xray_overlay.dart` exporting the six new public types: `XRayNode`, `XRayStateSummary`, `XRayBoxLabel`, `XRayBoxColor`, `XRayBoundingBox`, `XRayDetailPanel`, `XRayOverlayState`, `XRayShakeDetector`. File: `lib/src/plugins/xray/xray_overlay.dart`.

## Phase 2: Core (User Story 1 — Activate X-Ray Overlay, P1)

The MVP goal: shake/CLI activation toggles the overlay; release mode strips all paths.

- [ ] T03 [T] US1 RED: Write `test/plugins/xray/xray_overlay_state_test.dart` with the following behaviors:
  - `activate()` sets `isActive = true` when not in release mode.
  - `activate()` is a no-op when `isReleaseMode: true` (constructor param) — `isActive` stays `false`.
  - `deactivate()` sets `isActive = false`.
  - `register(node)` adds the node to the `nodes` snapshot.
  - `unregister(id)` removes the node by id.
  - `changes` stream emits the new `List<XRayBoundingBox>` snapshot after `register`/`unregister`/state update.
  - When `isReleaseMode: true`, `register`/`unregister`/`activate` are all no-ops (snapshot stays empty).
- [ ] T04 US1 GREEN: Implement `lib/src/plugins/xray/xray_overlay_state.dart` (registry + Stream + release guard). Passes T03.
- [ ] T05 [T] US1 RED: Write `test/plugins/xray/xray_node_test.dart` covering:
  - `XRayNode(...)` constructor with required fields + `children` defaulting to `[]`.
  - `toJson()` produces the canonical JSON shape: `{"id", "viewType", "enabled", "boundAction", "stateSummary": {...}, "children": [...]}`.
  - `XRayNode.fromJson(json)` round-trips through `toJson`.
  - `boundAction: null` is omitted from JSON.
  - `children: []` is preserved in JSON as `"children": []`.
- [ ] T06 US1 GREEN: Implement `lib/src/plugins/xray/xray_node.dart`. Passes T05.
- [ ] T07 [T] US1 RED: Write `test/plugins/xray/xray_shake_detector_test.dart`:
  - `XRayShakeDetector.instance` defaults to a no-op detector whose `shakes` stream is empty.
  - `XRayShakeDetector.instance = customDetector` is assignable; the custom detector's `shakes` stream is observable.
  - Resetting `instance = _NoOpShakeDetector()` after the test (cleanup).
- [ ] T08 US1 GREEN: Implement `lib/src/plugins/xray/xray_shake_detector.dart` (abstract + no-op default). Passes T07.

## Phase 3: Labels & Boxes (User Story 3 — Bounding Box Information Display, P2)

- [ ] T09 [T] US3 RED: Write `test/plugins/xray/xray_state_summary_test.dart`:
  - `XRayStateSummary(hasData: true, hasError: false, isLoading: false)` round-trips through `toJson`/`fromJson`.
  - `XRayStateSummary.empty` factory produces all-false.
  - `fromSignalSlice<T>(slice)` factory: when slice has data → `hasData: true`; when slice has error → `hasError: true`; when loading → `isLoading: true`. (Use a fake SignalSlice in test — see test fixture.)
  - `dataPreview` / `errorPreview` are truncated to ≤80 chars.
- [ ] T10 US3 GREEN: Implement `lib/src/plugins/xray/xray_state_summary.dart`. Passes T09.
- [ ] T11 [T] US3 RED: Write `test/plugins/xray/xray_box_label_test.dart`:
  - `XRayBoxLabel(nodeId: 'ProfileViewNode.editProfileButton', status: 'enabled', boundAction: 'onEditTapped', stateSummary: ...).format()` produces: `ProfileViewNode.editProfileButton | enabled | →onEditTapped | data✓`.
  - When `boundAction: null` → label omits the `→action` segment.
  - When `status: 'disabled'` → label shows `disabled`.
  - When `stateSummary` has all-false → label suffix is `idle`.
- [ ] T12 US3 GREEN: Implement `lib/src/plugins/xray/xray_box_label.dart`. Passes T11.
- [ ] T13 [T] US3 RED: Write `test/plugins/xray/xray_box_color_test.dart`:
  - `XRayBoxColor.forViewType('ProfileView')` returns a stable, non-null color (ARGB int).
  - `XRayBoxColor.forViewType('HomeView')` returns a different color than `ProfileView`.
  - `XRayBoxColor.forViewType('UnknownView')` returns a fallback neon color (deterministic by string hash).
  - Two calls with the same viewType return the SAME color (deterministic).
  - All neon colors have alpha=0xFF and R/G/B with at least one channel ≥0xA0 (visually neon).
- [ ] T14 US3 GREEN: Implement `lib/src/plugins/xray/xray_box_color.dart`. Passes T13.
- [ ] T15 [T] US3 RED: Write `test/plugins/xray/xray_bounding_box_test.dart`:
  - `XRayBoundingBox(nodeId, viewType, rect, label, color)` is immutable (const constructor where possible).
  - `rect` is a `XRayRect(left, top, width, height)` pure-Dart value type.
  - `toJson()` produces: `{"nodeId", "viewType", "rect": {...}, "label": "<formatted>", "color": <int>}`.
  - `XRayBoundingBox.fromNode(node, rect)` factory produces a box whose label/color come from the node.
- [ ] T16 US3 GREEN: Implement `lib/src/plugins/xray/xray_bounding_box.dart`. Passes T15.

## Phase 4: Detail Panel (User Story 2 — Inspect Individual Nodes, P2)

- [ ] T17 [T] US2 RED: Write `test/plugins/xray/xray_detail_panel_test.dart`:
  - `XRayDetailPanel(nodeId: 'n1', fullStateJson: '{...}')` round-trips through `toJson`/`fromJson`.
  - `XRayDetailPanel.fromNode(node, signalSliceData: ...)` produces `fullStateJson` containing: `nodeId`, `enabled`, `boundAction`, `state` (data/error/loading), `children` (recursively).
  - `fullStateJson` is valid JSON (parses without error).
  - When `stateSummary` is empty, `fullStateJson` includes `"state": {"data": null, "error": null, "loading": false}`.
- [ ] T18 US2 GREEN: Implement `lib/src/plugins/xray/xray_detail_panel.dart`. Passes T17.
- [ ] T19 US2 GREEN: Wire `XRayOverlayState.inspect(nodeId)` to return an `XRayDetailPanel?` (null if node not registered). Update `xray_overlay_state.dart` accordingly.

## Phase 5: CLI + Codegen Wiring (User Story 4 — CLI Toggle Lifecycle, P3)

- [ ] T20 [T] US4 RED: Write `test/commands/xray_status_json_test.dart`:
  - `zfa xray status --json` outputs `{"enabled": true}` or `{"enabled": false}` (JSON on stdout).
  - Without `--json`, the existing human-readable output is preserved.
  - In release mode (`--dart-define=dart.vm.product=true`), `status` reports `{"enabled": false, "release_mode": true}` (X-Ray is always-off).
- [ ] T21 US4 GREEN: Extend `lib/src/commands/xray_command.dart` `_XrayStatusCommand` with `--json` flag + release-mode guard. Passes T20.
- [ ] T22 [T] US4 RED: Extend `test/plugins/app_shell/app_shell_xray_test.dart` with:
  - When `xray: true`, `buildMain` emits `XRayOverlayState.activate()` (or `instance.activate()` — exact API TBD by T04) inside `if (kDebugMode) { ... }` AFTER `registerAllXRayDecks();`.
  - When `xray: false`, the source contains NO `XRayOverlayState` reference.
- [ ] T23 US4 GREEN: Update `lib/src/plugins/app_shell/builders/app_shell_builder.dart` to emit the new activate call. Passes T22.

## Phase 6: Release-Mode Strip Regression (SC-004)

- [ ] T24 [T] US1 RED: Write `test/regression/issue_181_xray_release_mode_strip_test.dart`:
  - `kXrayReleaseMode` is `bool.fromEnvironment('dart.vm.product')` (compile-time constant; in normal test runs it's `false`).
  - `shouldXRayBeActiveInCurrentBuild()` returns `!kXrayReleaseMode`.
  - When `XrayCommand('xray enable')` runs with `--dart-define=dart.vm.product=true` (simulated via constructor injection), the config flag is NOT written — i.e. enable is a no-op in release mode.
  - When `XRayOverlayState(isReleaseMode: true)` is constructed, calling `activate()` does not flip `isActive` — `isActive` stays `false`.
  - The Flutter codegen (`app_shell_builder.buildMain(xray: true)`) wraps the activate call in `if (kDebugMode) { ... }` so tree-shaking strips it in release builds.
- [ ] T25 US1 GREEN: Add the release-mode guard in `lib/src/core/xray_config.dart` (`kXrayReleaseMode`, `shouldXRayBeActiveInCurrentBuild`) + guard `_XrayEnableCommand`/`_XrayDisableCommand` to no-op in release. Passes T24.

## Phase 7: Export, Analyze, Verify

- [ ] T26 US1 Add `export 'src/plugins/xray/xray_overlay.dart';` to `lib/zuraffa.dart` (or a sub-barrel) ONLY if doing so does not break existing exports (verify by running `dart analyze` before and after).
- [ ] T27 Run `dart analyze` — must report ≤ baseline info-level issues (no new errors/warnings).
- [ ] T28 Run `dart test test/plugins/xray/ test/commands/xray_status_json_test.dart test/regression/issue_181_xray_release_mode_strip_test.dart test/plugins/app_shell/app_shell_xray_test.dart` — all must pass (green).
- [ ] T29 Write `specs/036-xray-visual-overlay/tdd/verification.md` mapping each SC-001..004 to tests that prove it, with the actual `dart test` pass/fail counts.
- [ ] T30 Commit artifacts: spec.md (existing), plan.md, tasks.md, tdd/test-list.md, tdd/verification.md, plus all new lib + test files. Push and open PR (closes #181).

## Phase 8: TDD Red Evidence (per behavior — recorded AFTER red tests are first run)

For each RED task above (T03, T05, T07, T09, T11, T13, T15, T17, T20, T22, T24), record the failure output in `specs/036-xray-visual-overlay/tdd/red/NN-behavior.md`. Format:

```markdown
# Red Evidence — <behavior-name>
**Test file**: `test/.../foo_test.dart`
**Behavior**: <one-line description>
**First-run output** (dart test, before implementation):
```
<paste the actual failure excerpt from `dart test`>
```
**Status**: RED ✓
```

This evidence is REQUIRED by the constitution's "Test-First" gate and is the only acceptable proof that TDD was followed (not test-after).
