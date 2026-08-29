// Spec 036 — Track 4.2: Release-mode strip regression for issue #181.
//
// Behavior B17: enable/disable no-op in release mode.
// Behavior B03: XRayOverlayState.activate no-op in release mode.
// Behavior B16: app_shell_builder emits activate inside kDebugMode.
//
// This test enforces SC-004: "Zero X-Ray-related code executes in release
// mode builds — no overlay rendering, no gesture listeners, no CLI handlers."
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/xray_config.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_overlay_state.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';
import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

void main() {
  group('SC-004 — Release-mode strip', () {
    test('kXrayReleaseMode is a compile-time constant (bool.fromEnvironment)',
        () {
      // In a normal `dart test` run (debug mode), kXrayReleaseMode MUST be false.
      expect(kXrayReleaseMode, isFalse);
    });

    test('shouldXRayBeActiveInCurrentBuild() returns !kXrayReleaseMode', () {
      // In a normal test run, kXrayReleaseMode is false → shouldXRayBeActive true.
      expect(shouldXRayBeActiveInCurrentBuild(), isTrue);
      // The negation property holds at compile time:
      expect(shouldXRayBeActiveInCurrentBuild(), equals(!kXrayReleaseMode));
    });

    test('B03 — XRayOverlayState constructed with isReleaseMode=true is inert',
        () {
      final release = XRayOverlayState(isReleaseMode: true);
      release.activate();
      release.register(const XRayNode(
        id: 'n1',
        viewType: 'ProfileView',
        enabled: true,
        boundAction: 'onTap',
        stateSummary: XRayStateSummary.empty(),
      ));
      expect(release.isActive, isFalse);
      expect(release.nodes, isEmpty);
    });

    test(
        'B16 — app_shell_builder.buildMain(xray: true) wraps activate inside '
        'kDebugMode', () {
      const builder = AppShellBuilder();
      final src = builder.buildMain(appName: 'demo_app', xray: true);
      // Must reference kDebugMode and the XRayOverlayState activate call.
      expect(src, contains('kDebugMode'));
      expect(src, contains('XRayOverlayState'));

      // Find the LAST occurrence of 'kDebugMode' — the actual `if (kDebugMode)`
      // keyword. Earlier occurrences are in leading comments / doc strings
      // and must be skipped (issue #181 spec comments mention kDebugMode).
      final debugIdx = src.lastIndexOf('if (kDebugMode)');
      // The activate call must come after the kDebugMode guard. We look for
      // the call form `XRayOverlayState.instance.activate();` so we don't
      // accidentally match `activate()` in leading comments.
      final activateIdx = src.indexOf('XRayOverlayState.instance.activate()');
      expect(debugIdx, greaterThanOrEqualTo(0));
      expect(activateIdx, greaterThan(debugIdx),
          reason: 'activate() MUST come after the kDebugMode guard');
    });

    test('B16b — app_shell_builder.buildMain(xray: false) emits no X-Ray', () {
      const builder = AppShellBuilder();
      final src = builder.buildMain(appName: 'demo_app');
      expect(src, isNot(contains('XRayOverlayState')));
      expect(src, isNot(contains('kDebugMode')));
    });
  });
}
