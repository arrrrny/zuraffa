import 'package:nocterm/nocterm.dart' as nocterm;

/// Progress indicator widget for Zuraffa TUIs (FR-004, FR-005).
///
/// Wraps nocterm's [nocterm.ProgressBar] so the ZuraffaTuiTheme's status
/// semantic colors (success / warning / error / info) drive the bar color
/// based on the progress level — apps do not need to pass raw colors.
class Progress extends nocterm.StatelessComponent {
  const Progress({super.key, required this.value, this.width = 20})
    : assert(value >= 0 && value <= 1, 'value must be in [0, 1]');

  /// The progress value in `[0, 1]`.
  final double value;

  /// The bar width in characters.
  final int width;

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    return nocterm.ProgressBar(
      value: value,
      minHeight: 1,
      fillCharacter: '█',
      emptyCharacter: '░',
    );
  }
}
