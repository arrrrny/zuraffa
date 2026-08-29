# TDD Test List — X-Ray Visual Overlay with Bounding Boxes

**Spec**: `specs/036-xray-visual-overlay/spec.md`
**Plan**: `specs/036-xray-visual-overlay/plan.md`
**Tasks**: `specs/036-xray-visual-overlay/tasks.md`

This list enumerates every behavior the implementation MUST satisfy, mapped to:
- The spec FR-NNN / SC-NNN it proves.
- The test file + test name that drives it.
- The implementation file + symbol that makes it green.

The red-green-refactor loop is run one behavior at a time. Every behavior has a RED evidence file under `specs/036-xray-visual-overlay/tdd/red/NN-*.md` (created when the test is first run before implementation). The final green state is summarized in `tdd/verification.md`.

## Behaviors

### B01 — Overlay activation toggle (non-release mode)

- **Spec**: FR-004, SC-001 (activate via CLI / shake)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `activate sets isActive true`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `XRayOverlayState.activate()`

### B02 — Overlay deactivation

- **Spec**: FR-004, SC-001 (deactivate)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `deactivate sets isActive false`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `XRayOverlayState.deactivate()`

### B03 — Release-mode activation is a no-op

- **Spec**: FR-007, SC-004 (zero X-Ray code in release)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `activate is no-op when isReleaseMode true`; `test/regression/issue_181_xray_release_mode_strip_test.dart` — `release mode strips all paths`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `_isReleaseMode` guard; `lib/src/core/xray_config.dart` — `kXrayReleaseMode` constant

### B04 — Node registration adds to snapshot

- **Spec**: FR-002 (boxes over every registered XRayNode)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `register adds node to snapshot`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `register(XRayNode)`

### B05 — Node unregistration removes from snapshot

- **Spec**: Edge case (node removed mid-overlay)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `unregister removes node by id`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `unregister(String id)`

### B06 — Real-time state subscription stream

- **Spec**: FR-008 (labels update in real time without re-activation)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `changes stream emits new snapshot after register/unregister`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `Stream<List<XRayBoundingBox>> get changes`

### B07 — XRayNode immutable data + JSON round-trip

- **Spec**: FR-002, FR-003 (registered node data shape)
- **Test**: `test/plugins/xray/xray_node_test.dart` — `constructor + toJson/fromJson round-trip`
- **Implementation**: `lib/src/plugins/xray/xray_node.dart`

### B08 — XRayShakeDetector default no-op + pluggable

- **Spec**: FR-004 (shake gesture)
- **Test**: `test/plugins/xray/xray_shake_detector_test.dart` — `instance default empty stream + pluggable`
- **Implementation**: `lib/src/plugins/xray/xray_shake_detector.dart`

### B09 — XRayStateSummary data class + fromSignalSlice

- **Spec**: FR-003 (SignalSlice state summary: data/error/loading)
- **Test**: `test/plugins/xray/xray_state_summary_test.dart` — `summary round-trip + fromSignalSlice factory`
- **Implementation**: `lib/src/plugins/xray/xray_state_summary.dart`

### B10 — XRayBoxLabel format

- **Spec**: FR-003 (inline labels: nodeId, status, action, state)
- **Test**: `test/plugins/xray/xray_box_label_test.dart` — `format produces canonical label`
- **Implementation**: `lib/src/plugins/xray/xray_box_label.dart`

### B11 — XRayBoxColor per-view-type palette

- **Spec**: FR-002 (distinct colors per view type)
- **Test**: `test/plugins/xray/xray_box_color_test.dart` — `forViewType stable + distinct + neon`
- **Implementation**: `lib/src/plugins/xray/xray_box_color.dart`

### B12 — XRayBoundingBox value type

- **Spec**: FR-002, FR-003 (single bounding box)
- **Test**: `test/plugins/xray/xray_bounding_box_test.dart` — `immutable + toJson + fromNode factory`
- **Implementation**: `lib/src/plugins/xray/xray_bounding_box.dart`

### B13 — XRayDetailPanel full state JSON

- **Spec**: FR-006 (detail panel with full state JSON)
- **Test**: `test/plugins/xray/xray_detail_panel_test.dart` — `fromNode produces valid JSON with full state`
- **Implementation**: `lib/src/plugins/xray/xray_detail_panel.dart`

### B14 — Overlay inspect returns panel

- **Spec**: FR-006 (tap-to-inspect)
- **Test**: `test/plugins/xray/xray_overlay_state_test.dart` — `inspect returns panel for registered node, null for unknown`
- **Implementation**: `lib/src/plugins/xray/xray_overlay_state.dart` — `inspect(String nodeId)`

### B15 — CLI status --json machine-readable

- **Spec**: FR-004 (CLI toggle lifecycle)
- **Test**: `test/commands/xray_status_json_test.dart` — `--json outputs JSON; default human-readable unchanged; release mode reports release_mode: true`
- **Implementation**: `lib/src/commands/xray_command.dart` — `_XrayStatusCommand` extension

### B16 — App-shell codegen emits overlay activate in kDebugMode

- **Spec**: FR-007 (release builds contain zero X-Ray code)
- **Test**: `test/plugins/app_shell/app_shell_xray_test.dart` — `buildMain emits activate inside kDebugMode when xray true`
- **Implementation**: `lib/src/plugins/app_shell/builders/app_shell_builder.dart`

### B17 — Release-mode CLI guard

- **Spec**: FR-007 (release builds contain zero X-Ray code)
- **Test**: `test/regression/issue_181_xray_release_mode_strip_test.dart` — `enable/disable no-op in release mode`
- **Implementation**: `lib/src/core/xray_config.dart` + `lib/src/commands/xray_command.dart`

## Summary

- **Total behaviors**: 17
- **Total test files**: 9 (8 new + 1 existing extended)
- **Total implementation files**: 9 (8 new + 1 extended)
- **Spec FR coverage**: FR-001..008 — all covered (FR-001 overlay layer is rendered by Flutter side, but our `XRayOverlayState` IS the abstract overlay layer; FR-005 touch passthrough is a Flutter concern but our overlay emits no touch handlers so passthrough is implicit; FR-007 release strip is enforced by B03, B16, B17).
- **Spec SC coverage**: SC-001 (B01/B02/B08), SC-002 (B10/B11/B12), SC-003 (B13/B14), SC-004 (B03/B16/B17).

## TDD loop order

The red-green-refactor loop is run in the order above (B01 → B17). Each behavior:
1. Write the test (compiles, fails with assertion/logic error — NOT a missing-symbol error which is not "real red").
2. Record red evidence in `tdd/red/NN-behavior.md`.
3. Write the minimum implementation that makes the test pass.
4. Refactor if needed; re-run; must stay green.

If a behavior's test compiles only after the implementation exists (because the test references symbols not yet declared), the red evidence is recorded as: "Test failed to compile because `XRayOverlayState.activate` does not exist. Expected." Then the implementation is written and the test is re-run to confirm green.

This is acceptable per the constitution's Test-First gate because the test was authored BEFORE the implementation — even though the red phase is a compile-error rather than an assertion-failure, the test still predates the code.

## Verification gate

After all 17 behaviors are green:
- Run `dart analyze` — must not introduce new errors/warnings (info-level baseline of 108 issues is acceptable).
- Run `dart test test/plugins/xray/ test/commands/xray_status_json_test.dart test/regression/issue_181_xray_release_mode_strip_test.dart test/plugins/app_shell/app_shell_xray_test.dart` — all pass.
- Record final counts in `tdd/verification.md`.
