# Red Evidence — Release-mode strip + codegen kDebugMode guard

**Test file**: `test/regression/issue_181_xray_release_mode_strip_test.dart`
**Behaviors**: B03 (release no-op), B16 (codegen kDebugMode wrap),
B16b (codegen no-op when xray false), B17 (release CLI guard)
**Spec**: FR-007, SC-004 (zero X-Ray code in release builds)

## First-run output (before implementation)

```
$ dart test test/regression/issue_181_xray_release_mode_strip_test.dart

Failed to load "test/regression/issue_181_xray_release_mode_strip_test.dart":
  Error: Method not found: 'kXrayReleaseMode' (in xray_config.dart).
  Error: Method not found: 'shouldXRayBeActiveInCurrentBuild' (in xray_config.dart).
  Error: Method not found: 'XRayOverlayState' (in xray_overlay_state.dart).
  Error: app_shell_builder.buildMain does NOT emit 'XRayOverlayState' when xray true.
```

**Status**: RED ✓ — four sub-tests, all initially failing because:
1. `kXrayReleaseMode` / `shouldXRayBeActiveInCurrentBuild` did not exist in
   `lib/src/core/xray_config.dart`.
2. `XRayOverlayState` did not exist yet.
3. `AppShellBuilder.buildMain(xray: true)` did not emit
   `XRayOverlayState.instance.activate()` inside `if (kDebugMode)`.

## Second-run output (after initial implementation, before kDebugMode guard fix)

```
00:00 +3 -1: B16 — app_shell_builder.buildMain(xray: true) wraps activate inside kDebugMode [E]
  Expected: a value greater than <948>
    Actual: <289>
  activate() MUST come after the kDebugMode guard
```

Root cause: the leading comment in the generated `main.dart` referenced
`XRayOverlayState.instance.activate()` verbatim, so `src.indexOf(...)`
matched the comment occurrence (position 289) BEFORE the actual
`if (kDebugMode)` block (position 948). Fixed in two ways:
1. Changed the leading comment to NOT mention `activate()` verbatim
   (describes the behavior in prose instead).
2. Tightened the test assertion to look for `if (kDebugMode)` (the keyword
   form) via `lastIndexOf` so earlier matches in spec comments don't shadow
   the actual guard.

## Resolution

Implementations:
- `lib/src/core/xray_config.dart`: added `kXrayReleaseMode`,
  `shouldXRayBeActiveInCurrentBuild()`, `xrayConfigPathFor(root)`.
- `lib/src/plugins/xray/xray_overlay_state.dart`: `_isReleaseMode` guard on
  every public method.
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart`: extended the
  kDebugMode block to emit `XRayOverlayState.instance.activate()` after
  `registerAllXRayDecks();` (inside the guard so tree-shaking strips it in
  release builds). Reworked the leading comment to not mention `activate()`
  verbatim.

Subsequent run (green):
```
00:00 +5: All tests passed!
```
