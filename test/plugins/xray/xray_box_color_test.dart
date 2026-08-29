// Spec 036 — Track 4.2: XRayBoxColor per-view-type palette tests.
//
// Behavior B11: forViewType stable + distinct + neon.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_box_color.dart';

void main() {
  group('XRayBoxColor', () {
    test('forViewType returns a non-null int', () {
      final c = XRayBoxColor.forViewType('ProfileView');
      expect(c, isNotNull);
      expect(c, isA<int>());
    });

    test('forViewType is stable — same input same output', () {
      final a = XRayBoxColor.forViewType('ProfileView');
      final b = XRayBoxColor.forViewType('ProfileView');
      expect(a, equals(b));
    });

    test('forViewType is distinct per viewType', () {
      final profile = XRayBoxColor.forViewType('ProfileView');
      final home = XRayBoxColor.forViewType('HomeView');
      final settings = XRayBoxColor.forViewType('SettingsView');
      expect(profile, isNot(equals(home)));
      expect(profile, isNot(equals(settings)));
      expect(home, isNot(equals(settings)));
    });

    test('forViewType handles unknown view deterministically', () {
      // Two calls with same unknown viewType must give same color.
      final a = XRayBoxColor.forViewType('SomeRandomView');
      final b = XRayBoxColor.forViewType('SomeRandomView');
      expect(a, equals(b));
    });

    test('all colors have alpha=0xFF (top byte)', () {
      for (final v in [
        'ProfileView',
        'HomeView',
        'SettingsView',
        'SearchView',
        'CartView',
        'UnknownXYZ',
      ]) {
        final c = XRayBoxColor.forViewType(v);
        // Alpha is the top 8 bits — 0xFF00_0000 = 0xFF << 24.
        final alpha = (c >> 24) & 0xFF;
        expect(alpha, 0xFF, reason: 'view "$v" color must be fully opaque');
      }
    });

    test('all colors have at least one R/G/B channel >= 0xA0 (neon)', () {
      for (final v in [
        'ProfileView',
        'HomeView',
        'SettingsView',
        'SearchView',
        'CartView',
        'UnknownXYZ',
        'A',
        'B',
      ]) {
        final c = XRayBoxColor.forViewType(v);
        final r = (c >> 16) & 0xFF;
        final g = (c >> 8) & 0xFF;
        final b = c & 0xFF;
        final maxChannel = [r, g, b].reduce((a, b) => a > b ? a : b);
        expect(
          maxChannel,
          greaterThanOrEqualTo(0xA0),
          reason: 'view "$v" must have a neon-bright channel',
        );
      }
    });

    test('toArgbString returns ARGB hex string', () {
      final c = XRayBoxColor.forViewType('ProfileView');
      final s = XRayBoxColor.toArgbString(c);
      expect(s, startsWith('#FF'));
      expect(s.length, 9); // '#' + 8 hex chars
    });
  });
}
