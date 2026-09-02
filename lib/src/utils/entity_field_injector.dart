/// Correct, body-scoped field insertion for zorphy entity files.
///
/// Issue #759: zorphy 2.3.1's `EntityCreator._insertFields` computes the
/// insertion point with `content.indexOf('{', classMatch.end)` — but its
/// class regex (`abstract class \$Name\s*\{`) already consumed the opening
/// brace. For an EMPTY class body (the tdd cycle's default entity, created
/// field-less by `zfa entity create`) there is no second brace anywhere:
/// `indexOf` returns -1, `insertPosition` becomes 0, and the field getters
/// are prepended at byte 0 — above the file header, imports, and class
/// declaration — producing invalid Dart that breaks build_runner.
///
/// This helper provides the positions the dependency should have computed:
///
///  * the insertion point is scoped to the TARGET class body (getters in
///    later classes of the same file — e.g. inline sealed subtypes — are
///    never stolen as anchors), and
///  * a `repairPrepended` that recognizes the exact corruption signature
///    (`updated == <prepended block> + <original>`) and re-inserts the
///    prepended getters where they belong.
class EntityFieldInjector {
  const EntityFieldInjector._();

  /// Returns the index INSIDE the `abstract class $<className>` body where
  /// new members should be inserted: after the last existing getter of that
  /// class, or immediately after the opening brace when the body is empty.
  /// Returns -1 when the class declaration cannot be found.
  static int findInsertPosition(String content, String className) {
    final classMatch = RegExp(
      r'abstract class \$+' + className + r'\s*\{',
    ).firstMatch(content);
    if (classMatch == null) return -1;

    final bodyOpen = classMatch.end - 1; // the consumed `{`
    final bodyClose = _findBodyClose(content, bodyOpen);
    final bodyEnd = bodyClose == -1 ? content.length : bodyClose;

    final getterPattern = RegExp(r'^\s*\S+\s+get\s+\w+;', multiLine: true);
    final getters = getterPattern.allMatches(
      content.substring(classMatch.end, bodyEnd),
    );
    if (getters.isEmpty) {
      return classMatch.end;
    }
    return classMatch.end + getters.last.end;
  }

  /// Inserts [block] into [content] at the position computed by
  /// [findInsertPosition]. Throws [StateError] when the class declaration
  /// cannot be found.
  static String inject(String content, String className, String block) {
    final position = findInsertPosition(content, className);
    if (position == -1) {
      throw StateError('Could not find class definition for $className');
    }
    return content.substring(0, position) + block + content.substring(position);
  }

  /// Recognizes the #759 corruption signature — `updated` is exactly
  /// `<prepended member block>` followed by the untouched [original] — and
  /// returns the repaired file with the prepended block re-inserted inside
  /// the `abstract class $<className>` body. Returns null when [updated]
  /// does not carry the signature (i.e. the dependency inserted correctly,
  /// or a different change was applied), in which case callers must keep
  /// [updated] as-is.
  static String? repairPrepended({
    required String original,
    required String updated,
    required String className,
  }) {
    if (updated.length <= original.length) return null;
    if (!updated.endsWith(original)) return null;

    final prepended = updated.substring(0, updated.length - original.length);
    final position = findInsertPosition(original, className);
    if (position == -1) return null;

    return original.substring(0, position) +
        prepended +
        original.substring(position);
  }

  /// Walks the class body from [openBraceIndex] and returns the index of the
  /// matching closing brace, or -1 when unbalanced. Line comments, block
  /// comments, and string literals are skipped so braces inside them cannot
  /// derail the scan (generated entity files contain only declarations, but
  /// hand-edited files may carry comments).
  static int _findBodyClose(String content, int openBraceIndex) {
    var depth = 0;
    var i = openBraceIndex;
    while (i < content.length) {
      final char = content[i];
      if (char == '/' && i + 1 < content.length) {
        final next = content[i + 1];
        if (next == '/') {
          final eol = content.indexOf('\n', i);
          i = eol == -1 ? content.length : eol + 1;
          continue;
        }
        if (next == '*') {
          final end = content.indexOf('*/', i + 2);
          i = end == -1 ? content.length : end + 2;
          continue;
        }
      }
      if (char == '\'' || char == '"') {
        i = _skipString(content, i, char);
        continue;
      }
      if (char == '{') {
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return -1;
  }

  static int _skipString(String content, int start, String quote) {
    var i = start + 1;
    while (i < content.length) {
      final char = content[i];
      if (char == r'\') {
        i += 2;
        continue;
      }
      if (char == quote) {
        return i + 1;
      }
      // A single-quoted string terminated by a newline was never a string.
      if (char == '\n') return i + 1;
      i++;
    }
    return i;
  }
}
