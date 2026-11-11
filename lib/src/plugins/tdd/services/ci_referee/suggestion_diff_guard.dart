/// Suggestion diff guard (issue #2064): stands between "review comment
/// rendered" and "review comment published" so a ```diff suggestion whose
/// added lines would break a block comment is never posted.
///
/// Issue #2064: `zuraffa-review[bot]`'s inline suggestion on
/// arrrrny/raptorr#504 (review comment 4532260043) proposed a docblock
/// reword whose added lines contain the `**/*.spec.ts` glob — the `*/`
/// inside `**/` closes the enclosing `/** ... */` block comment when the
/// suggestion is applied verbatim, and the remainder of the file is parsed
/// as live code (`error: Unexpected *`). The suggestion generator did not
/// account for the destination context: text destined for inside a block
/// comment must not contain the terminator sequence `*/`.
///
/// The guard is pure string work — no I/O, no analyzer. For every
/// ```diff fenced block in a comment body it:
///
/// - extracts the block the way CommonMark closes a fence: the closing
///   fence occupies its own line (at most three spaces of indent, nothing
///   on the line but backticks and trailing whitespace) and is at least as
///   long as the opening fence — an inline ``` inside a diff line cannot
///   terminate extraction early (PR #2065 review finding). A CRLF comment
///   body — fence lines ending `\r\n` — extracts and scans the same way
///   (PR #2065 second review finding);
/// - splits the block at hunk (`@@`) and file boundaries and classifies
///   each hunk independently, so a docblock rewrite in one hunk is never
///   cancelled by plain-code removals in another (PR #2065 review
///   finding). A file boundary is the header's full syntax (`diff --git`,
///   `--- `, `+++ ` followed by the path) — an ADDED line whose content
///   begins with `++` (e.g. `++**/*.spec.ts`) reads as `+++…` in the diff
///   but is not a header, so it stays in its hunk and is scanned (PR #2065
///   second review finding);
/// - walks each hunk in order over two comment states: the PRE-IMAGE state
///   advances through context and removed lines, and each context line
///   re-anchors the additions' scan state to it; every added line is
///   scanned at that ORIGINAL position — the entry seed or the last
///   context's state, advanced only by the additions already applied — so
///   the hunk's own removals (a removed ` */` closer among them) never
///   reinterpret an addition (PR #2065 second review finding). When the
///   hunk itself carries no boundary signal the entry state is seeded from
///   line shapes: removed lines that are all comment-interior (`*`- or
///   `/*`-prefixed — the `/*` arm covers hunks that rewrite the docblock's
///   opening line, and only an opener WITHOUT its own `*/`: a line that
///   opens and closes itself is a complete comment, not interior), or, for
///   a pure insertion, added lines that are all comment-interior;
/// - when that state is inside a block comment, an added line that CLOSES
///   the comment with live code left over — a `*/` whose remainder on the
///   line is not whitespace — is flagged
///   `comment_terminator_in_suggestion`: applied verbatim it closes the
///   comment early. The same code flags a clean ENCLOSING closer (one
///   ending a comment the line did not open itself) when the hunk retains
///   content after it: those retained lines leave the comment with the
///   closer and become live code (PR #2065 second review finding). A line
///   that ends the comment cleanly with nothing retained after it (a bare
///   ` */` closer, or a reword whose new text ends with the closer — a
///   replacement that also removes the original closer included) is
///   allowed, and so is a complete `/** ... */` line that opens and closes
///   its own comment without exposing code.
///
/// A flagged suggestion is refused at the transport
/// ([GithubPrCommentPoster] runs this scan in its posting gate), matching
/// the issue's remedy: reword so the literal `*/` does not appear (e.g.
/// split the code span around the slash) or flag the suggestion as not
/// directly applicable.
library;

import 'snippet_compile_check.dart';

/// The block-comment safety scan for ```diff suggestion blocks.
abstract final class SuggestionDiffGuard {
  /// A ```diff fence whose closing fence is a real CommonMark closing
  /// fence: a line of its own, at most three spaces of indent, only
  /// backticks (at least as many as the opener captured in group 1) and
  /// trailing whitespace. Both fence line endings accept an optional `\r`
  /// so a CRLF comment body extracts the same block an LF body does —
  /// without it a `\r\n` body matches nothing and the posting gate would
  /// publish an unscanned suggestion (PR #2065 second review finding). An
  /// unterminated fence matches nothing, and an inline ``` mid-line can
  /// never close the block.
  static final RegExp _diffFence = RegExp(
    '(`{3,})diff[ \t]*\r?\n(.*?)^ {0,3}\\1`{0,}[ \t]*\r?\$',
    multiLine: true,
    dotAll: true,
  );

  /// Every ```diff fenced block in [body] (best-effort extraction, the
  /// same fence convention as [SnippetPostingGate]: an unterminated fence
  /// matches nothing).
  static List<String> diffBlocks(String body) =>
      _diffFence.allMatches(body).map((m) => m.group(2)!).toList();

  /// Scans every ```diff block in [body]; one
  /// `comment_terminator_in_suggestion` issue per offending added line.
  /// Empty when there is nothing to scan or every block is safe.
  static List<SnippetValidationIssue> scanBody(String body) {
    final issues = <SnippetValidationIssue>[];
    for (final block in diffBlocks(body)) {
      issues.addAll(scanBlock(block));
    }
    return issues;
  }

  /// Scans one diff block's content (the lines between the fences): the
  /// block is split at hunk and file boundaries and each hunk is scanned
  /// independently — the hunks share no classification state.
  static List<SnippetValidationIssue> scanBlock(String diffBlock) {
    final issues = <SnippetValidationIssue>[];
    for (final hunk in _splitHunks(diffBlock)) {
      issues.addAll(_scanHunk(hunk));
    }
    return issues;
  }

  /// A line at which one hunk ends and the next (or the next file) begins.
  /// The `---`/`+++` file headers are recognized by their full syntax —
  /// marker, space, path — not by the marker alone: an added line whose
  /// CONTENT begins with `++` reads as `+++…` in the diff (e.g. the added
  /// glob line `++**/*.spec.ts`), and dropping it as a header would let
  /// its `*/` escape the scan (PR #2065 second review finding).
  static bool _isDiffBoundary(String line) =>
      line.startsWith('@@') ||
      line.startsWith('diff --git') ||
      line.startsWith('--- ') ||
      line.startsWith('+++ ');

  /// Splits [diffBlock] at hunk (`@@`) and file (`diff --git`, `---`,
  /// `+++`) boundaries; the boundary lines themselves are dropped. A block
  /// with no boundaries (the GitHub suggestion shape) is one hunk.
  static List<List<String>> _splitHunks(String diffBlock) {
    final hunks = <List<String>>[];
    var current = <String>[];
    for (final line in diffBlock.split('\n')) {
      if (_isDiffBoundary(line)) {
        if (current.isNotEmpty) hunks.add(current);
        current = <String>[];
        continue;
      }
      current.add(line);
    }
    if (current.isNotEmpty) hunks.add(current);
    return hunks;
  }

  /// Walks one hunk's lines in order over two comment states: [preImage]
  /// is the file's pre-image content — context and removed lines advance
  /// it — and every added line is scanned at the state of its ORIGINAL
  /// position: the entry seed or the last context line's state, advanced
  /// only by the additions already applied before it. A hunk's own
  /// removals therefore never reinterpret an addition — the removed ` */`
  /// closer of a replacement cannot close the comment the replacement's
  /// addition is applied inside (PR #2065 second review finding) — while
  /// a comment opened on an earlier unchanged or removed line still
  /// participates through the entry seed and the context re-anchoring, and
  /// each applied addition advances the scan state as the file's
  /// post-image content.
  static List<SnippetValidationIssue> _scanHunk(List<String> lines) {
    final removed = <String>[];
    final added = <String>[];
    for (final raw in lines) {
      if (raw.startsWith('-')) {
        removed.add(raw.substring(1));
      } else if (raw.startsWith('+')) {
        added.add(raw.substring(1));
      }
    }

    final issues = <SnippetValidationIssue>[];
    var preImage = _entryState(removed: removed, added: added);
    var atOriginal = preImage;
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      if (raw.startsWith('-')) {
        preImage = _scanLine(raw.substring(1), preImage).endsInComment;
      } else if (raw.startsWith('+')) {
        final content = raw.substring(1);
        final scan = _scanLine(content, atOriginal);
        if (scan.closesEarly) {
          issues.add(_terminatorIssue(content));
        } else if (scan.closesEnclosing &&
            _retainsContent(lines.sublist(i + 1))) {
          issues.add(_retainedContextIssue(content));
        }
        atOriginal = scan.endsInComment;
      } else {
        preImage = _scanLine(raw, preImage).endsInComment;
        atOriginal = preImage;
      }
    }
    return issues;
  }

  /// Whether any post-image line would remain in the applied file after a
  /// clean enclosing closer: retained context lines and later additions
  /// become live code once the closer ends the comment they were written
  /// inside; removals drop out with the hunk, and blank lines are code-
  /// free either way.
  static bool _retainsContent(List<String> lines) =>
      lines.any((raw) => !raw.startsWith('-') && raw.trim().isNotEmpty);

  /// The state the hunk's walk starts in, seeded from line shapes when the
  /// hunk reveals no boundary of its own: removed lines that are all
  /// comment-interior mean the hunk rewrites a docblock body; a pure
  /// insertion whose added lines are all comment-interior targets the
  /// inside of a block comment the same way. A hunk with no such signal
  /// starts outside a comment and relies on its context lines.
  static bool _entryState({
    required List<String> removed,
    required List<String> added,
  }) {
    final removedInterior = removed.where((l) => l.trim().isNotEmpty);
    if (removedInterior.isNotEmpty) {
      return removedInterior.every(_isCommentInteriorLine);
    }
    final addedInterior = added.where((l) => l.trim().isNotEmpty);
    return addedInterior.isNotEmpty &&
        addedInterior.every(_isCommentInteriorLine);
  }

  /// A docblock body line: trimmed of leading whitespace it starts with
  /// the `*` continuation marker (e.g. ` * module graph — ...`) or the
  /// `/*` opener (e.g. `/** Parses config files.` — a hunk that rewrites
  /// the docblock's first line is a comment target too). The `/*` arm
  /// accepts only an opener WITHOUT its own `*/`: a line that opens and
  /// closes itself is a COMPLETE comment, not comment interior — seeding
  /// "inside a comment" from it would turn a comment-replaced-by-code
  /// hunk (`/** Parses config files. */` → a code line carrying the glob)
  /// into a comment target and flag safe code (PR #2065 second review
  /// finding).
  static bool _isCommentInteriorLine(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('*')) return true;
    return trimmed.startsWith('/*') && !trimmed.contains('*/');
  }

  /// Scans [line] for comment markers starting in block-comment state
  /// [inComment]. [ScanResult.closesEarly] is set when a `*/` terminates
  /// the comment with non-whitespace text left on the line — applied
  /// verbatim that text is live code. [ScanResult.closesEnclosing] is set
  /// when a `*/` terminates a comment the line did NOT open itself (the
  /// enclosing one): everything the hunk retains after such a closer
  /// leaves the comment with it. [ScanResult.endsInComment] is the state
  /// after the line. String literals are not tracked (pure string work,
  /// fail-closed direction).
  static _ScanResult _scanLine(String line, bool inComment) {
    var i = 0;
    var closesEarly = false;
    var closesEnclosing = false;
    var enclosing = inComment;
    while (i < line.length) {
      if (inComment && line.startsWith('*/', i)) {
        if (line.substring(i + 2).trim().isNotEmpty) closesEarly = true;
        if (enclosing) closesEnclosing = true;
        enclosing = false;
        inComment = false;
        i += 2;
      } else if (!inComment && line.startsWith('/*', i)) {
        inComment = true;
        enclosing = false;
        i += 2;
      } else {
        i += 1;
      }
    }
    return _ScanResult(
      closesEarly: closesEarly,
      endsInComment: inComment,
      closesEnclosing: closesEnclosing,
    );
  }

  static SnippetValidationIssue _terminatorIssue(String line) =>
      SnippetValidationIssue(
        severity: SnippetIssueSeverity.error,
        code: 'comment_terminator_in_suggestion',
        message:
            'the added line `${line.trim()}` contains the terminator '
            'sequence `*/` while the suggestion rewrites a block comment '
            '— applied verbatim it closes the comment early and the '
            'remainder of the file no longer compiles (issue #2064). '
            'Reword so the literal `*/` does not appear (e.g. split the '
            'code span around the slash) or flag the suggestion as not '
            'directly applicable.',
      );

  static SnippetValidationIssue _retainedContextIssue(String line) =>
      SnippetValidationIssue(
        severity: SnippetIssueSeverity.error,
        code: 'comment_terminator_in_suggestion',
        message:
            'the added line `${line.trim()}` ends the enclosing block '
            'comment cleanly, but the hunk retains content after it — '
            'applied verbatim those retained lines leave the comment with '
            'the closer and become live code that no longer compiles '
            '(issue #2064, PR #2065 second review finding). Remove the '
            'retained lines in the same replacement, keep the comment '
            'open (drop the early closer), or flag the suggestion as not '
            'directly applicable.',
      );
}

/// One line's comment-marker scan result.
class _ScanResult {
  const _ScanResult({
    required this.closesEarly,
    required this.endsInComment,
    this.closesEnclosing = false,
  });

  /// A `*/` closed the comment with non-whitespace text left on the line.
  final bool closesEarly;

  /// Whether the line leaves the scanner inside a block comment.
  final bool endsInComment;

  /// A `*/` terminated a comment the line did not open itself — the
  /// enclosing one. Whatever the hunk retains after the line leaves the
  /// comment with the closer and becomes live code.
  final bool closesEnclosing;
}
