import 'package:nocterm/nocterm.dart' as nocterm;

/// A fixed-header table widget for Zuraffa TUIs (FR-004).
///
/// Built from Row + Column + Text (nocterm does not ship a Table widget).
/// Headers are always rendered first, then rows; columns are aligned by
/// padding each cell to the column's max-content width.
class Table extends nocterm.StatelessComponent {
  const Table({
    super.key,
    required this.headers,
    required this.rows,
    this.columnWidths,
  });

  /// The header labels for each column.
  final List<String> headers;

  /// The rows, where each inner list has one cell per column.
  final List<List<String>> rows;

  /// Optional explicit column widths. When `null`, columns auto-size to the
  /// max-content width across headers + cells in that column.
  final List<int>? columnWidths;

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    final widths = columnWidths ??
        List<int>.generate(headers.length, (i) {
          var max = headers[i].length;
          for (final row in rows) {
            if (i < row.length && row[i].length > max) {
              max = row[i].length;
            }
          }
          return max;
        });

    final headerCells = <nocterm.Component>[];
    for (var i = 0; i < headers.length; i++) {
      headerCells.add(_paddedCell(headers[i], widths[i], bold: true));
    }

    final rowComponents = <nocterm.Component>[];
    for (final row in rows) {
      final cells = <nocterm.Component>[];
      for (var i = 0; i < headers.length; i++) {
        final cell = i < row.length ? row[i] : '';
        cells.add(_paddedCell(cell, widths[i]));
      }
      rowComponents.add(nocterm.Row(children: cells));
    }

    return nocterm.Column(
      children: [
        nocterm.Row(children: headerCells),
        ...rowComponents,
      ],
    );
  }

  nocterm.Component _paddedCell(String text, int width, {bool bold = false}) {
    final padded = text.padRight(width);
    return nocterm.Text(padded);
  }
}
