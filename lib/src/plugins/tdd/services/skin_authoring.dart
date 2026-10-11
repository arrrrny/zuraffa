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

import 'widget_scaffold.dart' show scaffoldedMarker;

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
    if (finders.contains(scaffoldedMarker)) {
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
    final markerIndex = lines.indexWhere((l) => l.contains(scaffoldedMarker));
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

  static final RegExp _leadingWhitespacePattern = RegExp(r'^[ \t]*');

  static String _leadingWhitespace(String line) =>
      _leadingWhitespacePattern.firstMatch(line)?.group(0) ?? '';
}
