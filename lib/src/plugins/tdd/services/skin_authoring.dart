/// Skin-authoring seam (issue #1258) — the sanctioned transition of a
/// scaffolded widget test from placeholder finders to author-supplied
/// concrete finders.
///
/// `zfa tdd gen --kind widget` emits a widget test whose scenario
/// assertions are placeholder finders carrying [scaffoldedMarker] when no
/// finder is derivable from the acceptance description (issue #912
/// defect 3) — the honest state, because the button labels/layout live in
/// the not-yet-written view. `zfa tdd make` then refused to certify green
/// on exactly that test, demanding the author "replace the placeholder
/// finders ... and remove the marker", while NO zfa command performed the
/// replacement and `zfa tdd refactor`'s contract is "never edit tests":
/// the SKIN lane structurally dead-ended at `<id>:make` (issue #1258).
///
/// [SkinAuthoring] is the pure text-transform half of the sanctioned
/// authoring step (`zfa tdd make --author --finders-file <path>`): it
/// replaces the scaffolded scenario block with the author's concrete
/// finders and clears the marker. The command half (make_command.dart)
/// wraps it with the honesty gates: red-before-green re-certification,
/// the provenance-ledger hand-delta receipt, and byte-identical restore
/// on every refusal. The registry-owned test is mutated ONLY here —
/// inside the pipeline, with a receipt — never by hand.
library;

import 'widget_scaffold.dart' show isScaffoldedMarkerLine, scaffoldedMarker;

/// Raised when the authoring transition cannot proceed: the target
/// content is not scaffolded, the author finders are not concrete
/// assertions, or the finders themselves carry the scaffold marker.
class SkinAuthoringException implements Exception {
  const SkinAuthoringException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The placeholder statement the no-derivable-finder scaffold emits
/// (issue #912 defect 3): a greenable-by-a-bare-SizedBox mounted-view
/// smoke assertion the authoring transition must consume.
const String skinPlaceholderStatement =
    'expect(find.byWidget(view), findsOneWidget);';

abstract final class SkinAuthoring {
  /// Validates the author-supplied finders BEFORE any state changes:
  /// they must be non-empty, must not carry the scaffold marker (a
  /// marker-carrying block would re-scaffold the test it replaces), and
  /// must contain at least one concrete `expect`/`expectLater` assertion
  /// (prose or comments are not finders).
  static void validateAuthorFinders(String finders) {
    if (finders.trim().isEmpty) {
      throw const SkinAuthoringException(
        'the author finders are empty — supply concrete scenario-derived '
        'finder statements (find.text / find.byType ... assertions).',
      );
    }
    if (finders.split('\n').any(isScaffoldedMarkerLine)) {
      throw SkinAuthoringException(
        'the author finders carry the scaffold marker ($scaffoldedMarker) '
        '— authoring must replace the scaffold, never re-emit it.',
      );
    }
    if (!_assertionCall.hasMatch(finders)) {
      throw const SkinAuthoringException(
        'the author finders contain no concrete assertion — at least one '
        'expect(...) / expectLater(...) statement is required.',
      );
    }
    // Guard against the deadlock shape (issue #1855): flutter_test runs in a
    // FakeAsync zone, so an `await` of a subject/controller read that
    // happens BEFORE any pump never resolves — the Timer-backed mock read
    // (e.g. the generated ZikZakMockDataSource `Future.delayed(_delay)`)
    // only fires when a pump advances the fake clock. Pump first, then
    // await: kick the read off without awaiting, pump, then await the
    // already-completed future.
    _checkNoAwaitBeforePump(finders);
  }

  /// Returns [testContent] with the scaffolded scenario block — the
  /// marker comment block plus the mounted-view placeholder statement
  /// when present — replaced by [authorFinders] at the scaffold block's
  /// indentation. The marker is cleared by construction: the replaced
  /// block is the only place it appears.
  ///
  /// Throws [SkinAuthoringException] when [testContent] is not scaffolded
  /// (nothing to author) or [authorFinders] fails validation. Pure: no
  /// filesystem access, byte-identical output for identical inputs.
  static String patchedContent({
    required String testContent,
    required String authorFinders,
  }) {
    validateAuthorFinders(authorFinders);
    final lines = testContent.split('\n');
    final markerIndex = lines.indexWhere(isScaffoldedMarkerLine);
    if (markerIndex < 0) {
      throw SkinAuthoringException(
        'the test content carries no scaffold marker ($scaffoldedMarker) '
        '— there is nothing to author; re-run make without --author.',
      );
    }
    final indent = _leadingWhitespace(lines[markerIndex]);
    var end = markerIndex + 1;
    // Consume the marker comment block: the scaffold comment is emitted
    // as consecutive `//` lines under the marker (issue #912 defect 3
    // remedy text, and the #964 SEQUENCE variant).
    while (end < lines.length && lines[end].trimLeft().startsWith('//')) {
      end++;
    }
    // Consume the mounted-view placeholder statement when it directly
    // follows the comment block (the no-derivable-finder shape).
    if (end < lines.length && lines[end].trim() == skinPlaceholderStatement) {
      end++;
    }
    final replacement = authorFinders
        .split('\n')
        .map((l) => l.trim().isEmpty ? '' : '$indent$l')
        .join('\n');
    return [
      ...lines.sublist(0, markerIndex),
      ...replacement.split('\n'),
      ...lines.sublist(end),
    ].join('\n');
  }

  static final RegExp _assertionCall = RegExp(r'\b(expect|expectLater)\s*\(');

  static final RegExp _awaitKeyword = RegExp(r'\bawait\b');

  static final RegExp _pumpToken = RegExp(r'\bpump\w*\s*\(');

  static final RegExp _pumpAwait = RegExp(
    r'\bawait\s+(?:[A-Za-z_]\w*\.)*pump\w*\s*\(',
  );

  /// Refuses author finders that `await` a subject/controller read before
  /// any pump (issue #1855): under flutter_test's FakeAsync zone a
  /// Timer-backed mock read never resolves without a pump, so the await
  /// deadlocks the widget test. The sanctioned shape pumps first, then
  /// awaits the already-completed future.
  static void _checkNoAwaitBeforePump(String finders) {
    // Scan a comment/string-stripped view so the guard is honest in both
    // directions: a literal `await` inside a string (e.g.
    // `find.text('await')`) is not a real await, and a pump token that
    // appears only inside a comment cannot mask a real await-before-pump
    // deadlock. Whitespace/newline positions are preserved so the two
    // regex passes stay aligned.
    final code = _stripStringsAndComments(finders);
    final pumpMatch = _pumpToken.firstMatch(code);
    final firstPumpIndex = pumpMatch?.start ?? code.length;
    for (final match in _awaitKeyword.allMatches(code)) {
      if (match.start >= firstPumpIndex) continue;
      final tail = code.substring(match.start);
      if (_pumpAwait.matchAsPrefix(tail) != null) continue;
      throw const SkinAuthoringException(
        'the author finders await a subject/controller read before a pump — '
        'under flutter_test\'s FakeAsync zone this deadlocks the widget '
        'test (a Timer-backed mock read never fires without a pump). '
        'Pump first, then await: kick the read off without awaiting '
        '(`final Future<void> flip = state!.load();`), then '
        '`await tester.pumpAndSettle();`, then `await flip;` '
        '(pump-before-await / pump-then-await ordering).',
      );
    }
  }

  /// Replaces the contents of string literals and comments with spaces
  /// (preserving length and newlines) so heuristic scans over the result
  /// ignore tokens that appear only inside those regions. Handles line
  /// comments, block comments, single/double-quoted strings and their
  /// triple-quoted variants.
  static String _stripStringsAndComments(String source) {
    final buf = StringBuffer();
    var i = 0;
    final n = source.length;
    while (i < n) {
      final c = source[i];
      // Line comment: // ... until newline.
      if (c == '/' && i + 1 < n && source[i + 1] == '/') {
        while (i < n && source[i] != '\n') {
          buf.write(' ');
          i++;
        }
        continue;
      }
      // Block comment: /* ... */.
      if (c == '/' && i + 1 < n && source[i + 1] == '*') {
        buf.write(' ');
        buf.write(' ');
        i += 2;
        while (i < n &&
            !(source[i] == '*' && i + 1 < n && source[i + 1] == '/')) {
          buf.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
        if (i < n) {
          buf.write(' ');
          buf.write(' ');
          i += 2;
        }
        continue;
      }
      // String literals.
      if (c == "'" || c == '"') {
        final quote = c;
        final triple =
            i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
        final qCount = triple ? 3 : 1;
        for (var k = 0; k < qCount; k++) {
          buf.write(source[i]);
          i++;
        }
        while (i < n) {
          if (!triple && source[i] == '\\') {
            buf.write(' ');
            i++;
            if (i < n) {
              buf.write(' ');
              i++;
            }
            continue;
          }
          if (triple) {
            if (source[i] == quote &&
                i + 2 < n &&
                source[i + 1] == quote &&
                source[i + 2] == quote) {
              buf.write(' ');
              buf.write(' ');
              buf.write(' ');
              i += 3;
              break;
            }
            buf.write(source[i] == '\n' ? '\n' : ' ');
            i++;
            continue;
          } else {
            if (source[i] == quote) {
              buf.write(source[i]);
              i++;
              break;
            }
            if (source[i] == '\n') {
              buf.write('\n');
              i++;
              break;
            }
            buf.write(' ');
            i++;
            continue;
          }
        }
        continue;
      }
      buf.write(c);
      i++;
    }
    return buf.toString();
  }

  static final RegExp _leadingWhitespacePattern = RegExp(r'^[ \t]*');

  static String _leadingWhitespace(String line) =>
      _leadingWhitespacePattern.firstMatch(line)?.group(0) ?? '';
}
