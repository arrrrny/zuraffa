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

/// The log's captured-output field (`CycleLogEntry.toMarkdown`).
const String _outputField = '- output:';

final RegExp _behaviorField = RegExp(r'^- behavior: ', multiLine: true);

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
/// - The entry's `- output:` field opens its fence either inline
///   (`- output: ``` `, the dialect committed in
///   `specs/068-simulation-di-binding/tdd/cycle-log.md`) or on the next line.
/// - A trailing `\r` (a CRLF checkout) never hides a closing fence.
///
/// Because a fence line that no `- output:` field accounts for — a stray
/// ` ``` ` inside captured output, or the legacy inline-opener dialect read
/// without inline support — can flip the fence parity and make the scan
/// swallow whole entries, the splitter takes a second pass that honours only
/// `- output:` fences and keeps it when it recovers entries (see
/// [_scanCycleLogSections]).
///
/// Tilde (`~~~`) fences are not tracked: `toMarkdown()` never writes one,
/// and a `## ` line inside a tilde block is out of contract.
///
/// Byte-compat: for any [raw] whose in-fence lines never start with `## `
/// at column 0 outside a fence, the result equals `raw.split('\n## ')`.
List<String> splitCycleLogSections(String raw) {
  final scan = _scanCycleLogSections(raw, outputFencesOnly: false);
  if (!scan.unclosedFence || !scan.freeStandingFence) return scan.sections;
  // The scan never rebalanced — the signature of a fence whose opener was
  // not the log's own. Where that reading swallowed entry-bearing sections,
  // the anchored reading is the honest one.
  final anchored = _scanCycleLogSections(raw, outputFencesOnly: true);
  final recovered = _behaviorSections(anchored.sections);
  if (recovered > _behaviorSections(scan.sections)) return anchored.sections;
  return scan.sections;
}

/// One fence-tracking pass over [raw]. With [outputFencesOnly] a fence opens
/// only where the log format says captured output does (on the entry's
/// `- output:` field or on the line after a bare one); otherwise any fence
/// line opens one, CommonMark-style.
_SectionScan _scanCycleLogSections(
  String raw, {
  required bool outputFencesOnly,
}) {
  final sections = <String>[];
  var chunkStart = 0;
  var lineStart = 0;
  var fenceLength = 0; // 0 = outside a fence; otherwise the opening length.
  var outputFencePending = false; // the previous line was a bare `- output:`.
  var freeStandingFence = false;
  final length = raw.length;
  while (lineStart < length) {
    final newline = raw.indexOf('\n', lineStart);
    final lineEnd = newline == -1 ? length : newline;
    // A CRLF checkout's `\r` is a line ending, not line content.
    final contentEnd = lineEnd > lineStart && raw[lineEnd - 1] == '\r'
        ? lineEnd - 1
        : lineEnd;

    var pos = lineStart;
    var indent = 0;
    while (pos < contentEnd && raw[pos] == ' ' && indent < 4) {
      pos++;
      indent++;
    }
    var ticks = 0;
    while (pos + ticks < contentEnd && raw[pos + ticks] == '`') {
      ticks++;
    }
    final fenceExpected = outputFencePending;
    outputFencePending = false;

    if (indent <= 3) {
      if (fenceLength == 0) {
        final outputFence = _outputFenceRun(raw, pos, contentEnd);
        if (outputFence > 0) {
          fenceLength = outputFence;
        } else if (outputFence == 0) {
          outputFencePending = true;
        } else if (ticks >= 3) {
          if (fenceExpected || !outputFencesOnly) {
            fenceLength = ticks;
            if (!fenceExpected) freeStandingFence = true;
          }
        } else if (pos == lineStart &&
            lineStart > 0 &&
            lineStart > chunkStart &&
            pos + 2 < contentEnd &&
            raw[pos] == '#' &&
            raw[pos + 1] == '#' &&
            raw[pos + 2] == ' ') {
          // Cut BEFORE the newline preceding the header and resume AFTER the
          // `## ` prefix, mirroring the legacy `split('\n## ')` which consumed
          // `\n## ` (4 chars) as the separator.
          sections.add(raw.substring(chunkStart, lineStart - 1));
          chunkStart = lineStart + 3;
        }
      } else if (ticks >= fenceLength &&
          _onlyWhitespace(raw, pos + ticks, contentEnd)) {
        fenceLength = 0;
      }
    }

    if (newline == -1) break;
    lineStart = newline + 1;
  }
  sections.add(raw.substring(chunkStart));
  return _SectionScan(sections, fenceLength != 0, freeStandingFence);
}

int _behaviorSections(List<String> sections) =>
    sections.where(_behaviorField.hasMatch).length;

/// The inline opening fence of the `- output:` field at [pos] (`[pos]` is
/// past the line's indent).
///
/// Returns the backtick run of `- output: ``` ` (the dialect committed in
/// `specs/068-simulation-di-binding/tdd/cycle-log.md`), `0` when the line is
/// a bare `- output:` whose fence opens on the next line, and `-1` when the
/// line is not an output field at all.
int _outputFenceRun(String raw, int pos, int end) {
  if (pos + _outputField.length > end) return -1;
  for (var i = 0; i < _outputField.length; i++) {
    if (raw[pos + i] != _outputField[i]) return -1;
  }
  var runEnd = end;
  while (runEnd > pos + _outputField.length &&
      (raw[runEnd - 1] == ' ' || raw[runEnd - 1] == '\t')) {
    runEnd--;
  }
  var runStart = runEnd;
  while (runStart > pos + _outputField.length && raw[runStart - 1] == '`') {
    runStart--;
  }
  if (runEnd - runStart >= 3) {
    for (var i = pos + _outputField.length; i < runStart; i++) {
      final c = raw[i];
      if (c != ' ' && c != '\t') return 0;
    }
    return runEnd - runStart;
  }
  for (var i = pos + _outputField.length; i < end; i++) {
    final c = raw[i];
    if (c != ' ' && c != '\t') return -1;
  }
  return 0;
}

bool _onlyWhitespace(String raw, int start, int end) {
  for (var i = start; i < end; i++) {
    final c = raw[i];
    if (c != ' ' && c != '\t' && c != '\r') return false;
  }
  return true;
}

class _SectionScan {
  const _SectionScan(this.sections, this.unclosedFence, this.freeStandingFence);

  /// The `## `-delimited chunks this pass produced.
  final List<String> sections;

  /// The pass ended still inside a fence (the parity never rebalanced).
  final bool unclosedFence;

  /// The pass opened a fence no `- output:` field accounts for.
  final bool freeStandingFence;
}
