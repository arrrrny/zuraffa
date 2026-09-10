/// Fence-aware section splitter for `tdd/cycle-log.md` (issue #1467).
///
/// Cycle-log entries embed captured test stdout verbatim inside fenced code
/// blocks (`- output:` followed by a bare ` ``` ` fence — see
/// `CycleLogEntry.toMarkdown`). Every reader used to section the log with a
/// plain-text `raw.split('\n## ')`, so a captured line starting with
/// `## ` (Flutter banners, markdown-printing tests) created a PHANTOM
/// section: the real entry's trailing fields (`- kind:`, `- hash:`,
/// `- prev-hash:`) were stranded in the phantom chunk, evidence was
/// misattributed, and the doctor's hash-chain verification failed.
///
/// [splitCycleLogSections] tracks fence state line-by-line and only treats
/// a `## ` line OUTSIDE a fence as a section header. For logs whose captured
/// output contains no `## ` lines it produces byte-identical chunks to the
/// legacy `split('\n## ')` (no format change, no migration).
library;

/// Split [raw] cycle-log markdown into `## `-delimited sections, ignoring
/// `## ` lines inside fenced code blocks.
///
/// The contract mirrors the legacy `raw.split('\n## ')` exactly:
///
/// - A section header is a line beginning with `## ` at column 0 (the
///   legacy delimiter was the byte sequence `\n## `).
/// - The first chunk is everything before the newline that precedes the
///   first header line (the legacy `\n## ` delimiter consumed that newline);
///   each subsequent chunk starts AFTER its `## ` prefix, exactly like the
///   legacy split where the `\n## ` separator absorbed the prefix.
/// - A line inside a fenced code block is never a header. Fences are
///   CommonMark-flavoured: up to 3 leading spaces, an opening run of 3+
///   backticks (an info string like ` ```dart ` is allowed), and a closing
///   run of at least as many backticks with nothing else on the line.
///
/// Byte-compat: for any [raw] whose in-fence lines never start with `## `
/// at column 0 outside a fence, the result equals `raw.split('\n## ')`.
List<String> splitCycleLogSections(String raw) {
  final sections = <String>[];
  var chunkStart = 0;
  var lineStart = 0;
  var fenceLength = 0; // 0 = outside a fence; otherwise the opening length.
  final length = raw.length;
  while (lineStart < length) {
    final newline = raw.indexOf('\n', lineStart);
    final lineEnd = newline == -1 ? length : newline;

    var pos = lineStart;
    var indent = 0;
    while (pos < lineEnd && raw[pos] == ' ' && indent < 4) {
      pos++;
      indent++;
    }
    if (pos < lineEnd && indent <= 3) {
      var ticks = 0;
      while (pos + ticks < lineEnd && raw[pos + ticks] == '`') {
        ticks++;
      }
      if (ticks >= 3) {
        if (fenceLength == 0) {
          fenceLength = ticks;
        } else if (ticks >= fenceLength &&
            _onlyWhitespace(raw, pos + ticks, lineEnd)) {
          fenceLength = 0;
        }
      } else if (fenceLength == 0 &&
          pos == lineStart &&
          lineStart > 0 &&
          lineStart > chunkStart &&
          pos + 2 < lineEnd &&
          raw[pos] == '#' &&
          raw[pos + 1] == '#' &&
          raw[pos + 2] == ' ') {
        // Cut BEFORE the newline preceding the header and resume AFTER the
        // `## ` prefix, mirroring the legacy `split('\n## ')` which consumed
        // `\n## ` (4 chars) as the separator.
        sections.add(raw.substring(chunkStart, lineStart - 1));
        chunkStart = lineStart + 3;
      }
    }

    if (newline == -1) break;
    lineStart = newline + 1;
  }
  sections.add(raw.substring(chunkStart));
  return sections;
}

bool _onlyWhitespace(String raw, int start, int end) {
  for (var i = start; i < end; i++) {
    final c = raw[i];
    if (c != ' ' && c != '\t') return false;
  }
  return true;
}
