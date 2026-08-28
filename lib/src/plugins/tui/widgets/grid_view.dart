import 'package:nocterm/nocterm.dart' as nocterm;

/// Grid view widget for Zuraffa TUIs (FR-004).
///
/// Renders items in a grid with [crossAxisCount] columns. Each row is a
/// [nocterm.Row]; rows are stacked in a [nocterm.Column].
///
/// For large lists, prefer [nocterm.ListView] (which is lazy / virtualized);
/// [GridView] is for small fixed-size grids where the whole tree renders.
class GridView extends nocterm.StatelessComponent {
  const GridView({
    super.key,
    required this.crossAxisCount,
    required this.itemCount,
    required this.itemBuilder,
  });

  /// The number of columns in the grid.
  final int crossAxisCount;

  /// The total number of items.
  final int itemCount;

  /// Builds the component for item at index [i].
  final nocterm.Component Function(int i) itemBuilder;

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    final rows = <nocterm.Component>[];
    for (var i = 0; i < itemCount; i += crossAxisCount) {
      final cells = <nocterm.Component>[];
      for (var c = 0; c < crossAxisCount && i + c < itemCount; c++) {
        cells.add(itemBuilder(i + c));
      }
      rows.add(nocterm.Row(children: cells));
    }
    return nocterm.Column(children: rows);
  }
}
