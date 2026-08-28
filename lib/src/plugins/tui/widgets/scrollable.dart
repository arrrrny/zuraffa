import 'package:nocterm/nocterm.dart' as nocterm;

/// Scrollable region widget for Zuraffa TUIs (FR-004).
///
/// Wraps nocterm's [nocterm.SingleChildScrollView] so a child can scroll
/// when its content exceeds the available height.
class Scrollable extends nocterm.StatelessComponent {
  const Scrollable({super.key, required this.child, this.scrollController});

  /// The child to wrap in a scrollable region.
  final nocterm.Component child;

  /// Optional scroll controller for programmatic scroll.
  final nocterm.ScrollController? scrollController;

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    return nocterm.SingleChildScrollView(
      controller: scrollController,
      child: child,
    );
  }
}
