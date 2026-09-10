/// Text-wrapping helper for CLI usage/help rendering.
library;

import 'dart:math';

// Vendored from package:args 2.7.0 lib/src/utils.dart `wrapTextAsLines`
// (not publicly exported). Diverges from base _getCommandUsage: no
// Command.category grouping, no usageFooter, message not wrapped.
// License: BSD-3-Clause, (c) the Dart project authors.
// https://github.com/dart-lang/core/blob/main/pkgs/LICENSE
List<String> wrapTextAsLines(String text, {int start = 0, int? length}) {
  assert(start >= 0);
  bool isWhitespace(String text, int index) {
    var rune = text.codeUnitAt(index);
    return rune >= 0x0009 && rune <= 0x000D ||
        rune == 0x0020 ||
        rune == 0x0085 ||
        rune == 0x1680 ||
        rune == 0x180E ||
        rune >= 0x2000 && rune <= 0x200A ||
        rune == 0x2028 ||
        rune == 0x2029 ||
        rune == 0x202F ||
        rune == 0x205F ||
        rune == 0x3000 ||
        rune == 0xFEFF;
  }

  if (length == null) return text.split('\n');

  var result = <String>[];
  var effectiveLength = max(length - start, 10);
  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.length <= effectiveLength) {
      result.add(line);
      continue;
    }

    var currentLineStart = 0;
    int? lastWhitespace;
    for (var i = 0; i < line.length; ++i) {
      if (isWhitespace(line, i)) lastWhitespace = i;

      if (i - currentLineStart >= effectiveLength) {
        if (lastWhitespace != null) i = lastWhitespace;

        result.add(line.substring(currentLineStart, i).trim());

        while (isWhitespace(line, i) && i < line.length) {
          i++;
        }

        currentLineStart = i;
        lastWhitespace = null;
      }
    }
    result.add(line.substring(currentLineStart).trim());
  }
  return result;
}
