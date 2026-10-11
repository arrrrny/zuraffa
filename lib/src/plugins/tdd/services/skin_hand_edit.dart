/// `_XRaySkinHandEdit` — the source-level hand-edit annotation the skin
/// cycle scans and cross-checks (issue #1005).
///
/// The skin half may be hand-written (or AI-written); the loop accepts
/// hand-written skin code only if it conforms to the declared contract,
/// has tests, goes red before green, and carries this annotation
/// VERIFIED BY THE CYCLE — never trusted from the author's claim. The
/// annotation follows the `@XRayMock` precedent (`xray_deck_command`):
/// a regex-scanned source marker, not a Dart identifier, so a
/// hand-written view needs no framework import to carry it.
///
/// Shape (fields in the fixed order behavior, file, logged_at,
/// double-quoted; tolerant of line breaks and `///` comment
/// continuations between the fields):
///
/// ```dart
/// // _XRaySkinHandEdit(behavior: "W1",
/// //   file: "lib/src/presentation/pages/login/login_view.dart",
/// //   logged_at: "2026-09-05T00:00:00Z")
/// ```
library;

/// One scanned `_XRaySkinHandEdit(...)` annotation.
class SkinHandEdit {
  const SkinHandEdit({
    required this.behavior,
    required this.file,
    required this.loggedAt,
  });

  /// The behavior id the hand-edit belongs to (e.g. `W1`).
  final String behavior;

  /// The project-relative POSIX path of the hand-edited file.
  final String file;

  /// The ISO-8601 timestamp the author logged the edit at.
  final String loggedAt;

  /// Whether this annotation is the hand-edit record for [behaviorId]'s
  /// implementation at [subjectRelPath]: the cycle's cross-check —
  /// the behavior must be the row's id and the file must be the
  /// registry record's project-relative subject path.
  bool matches({required String behaviorId, required String subjectRelPath}) =>
      behavior == behaviorId && file == subjectRelPath;

  /// Whether [loggedAt] parses as ISO-8601 (DateTime.tryParse, the
  /// loosest honest gate — the receipt records the stamp verbatim).
  bool get hasValidTimestamp => DateTime.tryParse(loggedAt) != null;

  @override
  String toString() =>
      'SkinHandEdit(behavior: $behavior, file: $file, logged_at: $loggedAt)';
}

/// The `_XRaySkinHandEdit(` open token the scanner keys on.
const String kSkinHandEditToken = '_XRaySkinHandEdit(';

/// Scan every `_XRaySkinHandEdit(behavior: "...", file: "...",
/// logged_at: "...")` annotation out of [source].
///
/// Malformed annotations (missing fields, unbalanced quotes, wrong
/// order) are skipped silently — a malformed marker is not a hand-edit
/// record; the conformance check then reports the absence honestly.
List<SkinHandEdit> scanSkinHandEdits(String source) {
  final edits = <SkinHandEdit>[];
  final token = kSkinHandEditToken;
  var searchFrom = 0;
  while (true) {
    final open = source.indexOf(token, searchFrom);
    if (open < 0) break;
    final bodyStart = open + token.length;
    final close = _findClosingParen(source, bodyStart);
    if (close < 0) break; // truncated annotation — nothing more to scan
    final body = source.substring(bodyStart, close);
    final edit = _parseFields(body);
    if (edit != null) edits.add(edit);
    searchFrom = close + 1;
  }
  return edits;
}

/// The closing paren of the annotation body, quote- and depth-aware.
int _findClosingParen(String source, int from) {
  var depth = 1;
  var i = from;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '"' || ch == "'") {
      final quoteEnd = _skipQuoted(source, i);
      if (quoteEnd < 0) return -1;
      i = quoteEnd;
      continue;
    }
    if (ch == '(') depth++;
    if (ch == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return -1;
}

/// Skip a quoted literal starting at [start]; returns the index just
/// past its closing quote, or -1 when unterminated.
int _skipQuoted(String source, int start) {
  final quote = source[start];
  var i = start + 1;
  while (i < source.length) {
    if (source[i] == '\\') {
      i += 2;
      continue;
    }
    if (source[i] == quote) return i + 1;
    i++;
  }
  return -1;
}

/// Parse the three annotation fields out of [body] (already
/// paren-stripped; may span lines and carry `//`/`///` continuations).
SkinHandEdit? _parseFields(String body) {
  // Drop comment-continuation prefixes so wrapped annotations parse.
  final flattened = body
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'^\s*///?\s?'), ''))
      .join(' ');
  final behavior = _field(flattened, 'behavior');
  final file = _field(flattened, 'file');
  final loggedAt = _field(flattened, 'logged_at');
  if (behavior == null || file == null || loggedAt == null) return null;
  return SkinHandEdit(behavior: behavior, file: file, loggedAt: loggedAt);
}

/// The double-quoted value of `name:` in [body], or null.
String? _field(String body, String name) {
  final m = RegExp('$name:\\s*"([^"]*)"').firstMatch(body);
  return m?.group(1);
}
