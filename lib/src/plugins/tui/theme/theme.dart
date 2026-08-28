/// Shared theming system for Zuraffa TUIs (FR-005).
///
/// [ZuraffaTuiTheme] is the visual vocabulary applied uniformly across
/// screens: colors, emphasis, spacing, and status semantics. Every Zuraffa
/// TUI uses the same theme tokens so users see a consistent look-and-feel
/// across apps; per-app overrides are allowed via a custom [ZuraffaTuiTheme]
/// instance but the token set is fixed.
library;

import 'package:meta/meta.dart';

/// A semantic color token in the TUI theme vocabulary.
///
/// Each token maps to a foreground/background pair (ANSI 256-color or
/// truecolor hex). Tokens are *semantic* — apps refer to "primary",
/// "success", "warning" rather than raw ANSI codes so a theme can be
/// re-skinned without touching screen code.
@immutable
class TuiColor {
  const TuiColor(this.fg, this.bg, {this.bold = false, this.italic = false});

  /// Foreground color (hex, e.g. `#1f6feb`).
  final String fg;

  /// Background color (hex, e.g. `#0d1117`).
  final String bg;

  /// Bold emphasis flag.
  final bool bold;

  /// Italic emphasis flag.
  final bool italic;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuiColor &&
          runtimeType == other.runtimeType &&
          fg == other.fg &&
          bg == other.bg &&
          bold == other.bold &&
          italic == other.italic;

  @override
  int get hashCode => Object.hash(fg, bg, bold, italic);

  @override
  String toString() =>
      'TuiColor(fg: $fg, bg: $bg, bold: $bold, italic: $italic)';
}

/// Text emphasis levels (FR-005: "emphasis" vocabulary).
@immutable
class TuiEmphasis {
  const TuiEmphasis({
    required this.high,
    required this.medium,
    required this.low,
    required this.muted,
  });

  /// Highest emphasis — primary headings, active focus.
  final TuiColor high;

  /// Medium emphasis — secondary headings, labels.
  final TuiColor medium;

  /// Low emphasis — body text.
  final TuiColor low;

  /// Muted emphasis — hints, footnotes.
  final TuiColor muted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuiEmphasis &&
          high == other.high &&
          medium == other.medium &&
          low == other.low &&
          muted == other.muted;

  @override
  int get hashCode => Object.hash(high, medium, low, muted);
}

/// Spacing scale (FR-005: "spacing" vocabulary).
@immutable
class TuiSpacing {
  const TuiSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  final int xxs; // 0
  final int xs; // 1
  final int sm; // 2
  final int md; // 4
  final int lg; // 8
  final int xl; // 16

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuiSpacing &&
          xxs == other.xxs &&
          xs == other.xs &&
          sm == other.sm &&
          md == other.md &&
          lg == other.lg &&
          xl == other.xl;

  @override
  int get hashCode => Object.hash(xxs, xs, sm, md, lg, xl);
}

/// Status semantics (FR-005: "status semantics" vocabulary).
@immutable
class TuiStatusColors {
  const TuiStatusColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });

  final TuiColor success;
  final TuiColor warning;
  final TuiColor error;
  final TuiColor info;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TuiStatusColors &&
          success == other.success &&
          warning == other.warning &&
          error == other.error &&
          info == other.info;

  @override
  int get hashCode => Object.hash(success, warning, error, info);
}

/// The shared TUI theme vocabulary (FR-005).
///
/// A [ZuraffaTuiTheme] bundles:
/// * [primary] / [secondary] / [accent] brand colors,
/// * [emphasis] — text emphasis levels,
/// * [spacing] — spacing scale,
/// * [status] — success/warning/error/info semantic colors.
///
/// Every Zuraffa TUI uses the same token set so screens built from the
/// standard widget library look consistent across apps (SC-003).
@immutable
class ZuraffaTuiTheme {
  const ZuraffaTuiTheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.emphasis,
    required this.spacing,
    required this.status,
  });

  /// Brand primary color.
  final TuiColor primary;

  /// Brand secondary color.
  final TuiColor secondary;

  /// Accent / highlight color (selections, focus rings).
  final TuiColor accent;

  /// Default background.
  final TuiColor background;

  /// Text emphasis levels.
  final TuiEmphasis emphasis;

  /// Spacing scale.
  final TuiSpacing spacing;

  /// Status semantic colors.
  final TuiStatusColors status;

  /// The canonical default theme shipped with every Zuraffa TUI.
  ///
  /// Apps MAY construct a custom [ZuraffaTuiTheme] for branding, but the
  /// token set is fixed (FR-005). The defaults follow GitHub's dark-theme
  /// palette so Zuraffa TUIs feel familiar to terminal users.
  factory ZuraffaTuiTheme.defaultTheme() => const ZuraffaTuiTheme(
    primary: TuiColor('#58a6ff', '#0d1117', bold: true),
    secondary: TuiColor('#79c0ff', '#0d1117'),
    accent: TuiColor('#1f6feb', '#0d1117', bold: true),
    background: TuiColor('#c9d1d9', '#0d1117'),
    emphasis: TuiEmphasis(
      high: TuiColor('#f0f6fc', '#0d1117', bold: true),
      medium: TuiColor('#c9d1d9', '#0d1117'),
      low: TuiColor('#8b949e', '#0d1117'),
      muted: TuiColor('#484f58', '#0d1117', italic: true),
    ),
    spacing: TuiSpacing(xxs: 0, xs: 1, sm: 2, md: 4, lg: 8, xl: 16),
    status: TuiStatusColors(
      success: TuiColor('#3fb950', '#0d1117', bold: true),
      warning: TuiColor('#d29922', '#0d1117', bold: true),
      error: TuiColor('#f85149', '#0d1117', bold: true),
      info: TuiColor('#58a6ff', '#0d1117'),
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZuraffaTuiTheme &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          secondary == other.secondary &&
          accent == other.accent &&
          background == other.background &&
          emphasis == other.emphasis &&
          spacing == other.spacing &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
    primary,
    secondary,
    accent,
    background,
    emphasis,
    spacing,
    status,
  );

  @override
  String toString() => 'ZuraffaTuiTheme(primary: $primary, status: $status)';
}
