import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tui/theme/theme.dart';

void main() {
  group('ZuraffaTuiTheme (FR-005, SC-003)', () {
    test('A8 / U20: defaultTheme() returns a complete vocabulary — colors, '
        'emphasis, spacing, status semantics', () {
      final theme = ZuraffaTuiTheme.defaultTheme();

      // Primary / secondary / accent / background.
      expect(theme.primary, isA<TuiColor>());
      expect(theme.primary.fg, isNotEmpty);
      expect(theme.secondary, isA<TuiColor>());
      expect(theme.accent, isA<TuiColor>());
      expect(theme.background, isA<TuiColor>());

      // Emphasis levels.
      expect(theme.emphasis.high, isA<TuiColor>());
      expect(theme.emphasis.medium, isA<TuiColor>());
      expect(theme.emphasis.low, isA<TuiColor>());
      expect(theme.emphasis.muted, isA<TuiColor>());

      // Spacing scale.
      expect(theme.spacing.xxs, isA<int>());
      expect(theme.spacing.sm, lessThan(theme.spacing.lg));

      // Status semantics.
      expect(theme.status.success, isA<TuiColor>());
      expect(theme.status.warning, isA<TuiColor>());
      expect(theme.status.error, isA<TuiColor>());
      expect(theme.status.info, isA<TuiColor>());

      // Each status color must be distinct (semantic, not aesthetic).
      final statuses = {
        theme.status.success,
        theme.status.warning,
        theme.status.error,
        theme.status.info,
      };
      expect(statuses.length, 4, reason: 'each status color must be unique');
    });

    test('ZuraffaTuiTheme is immutable: same defaults are ==', () {
      final a = ZuraffaTuiTheme.defaultTheme();
      final b = ZuraffaTuiTheme.defaultTheme();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('Two themes with different primary colors are not equal', () {
      final a = ZuraffaTuiTheme.defaultTheme();
      final b = ZuraffaTuiTheme(
        primary: const TuiColor('#ffffff', '#000000'),
        secondary: a.secondary,
        accent: a.accent,
        background: a.background,
        emphasis: a.emphasis,
        spacing: a.spacing,
        status: a.status,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
