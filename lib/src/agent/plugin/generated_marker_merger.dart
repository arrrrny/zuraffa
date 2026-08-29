/// Idempotent write-merge for generated tool files (FR-008, FR-009, SC-003).
///
/// The [GeneratedMarkerMerger] preserves manual edits OUTSIDE the
/// `// GENERATED - DO NOT EDIT ... // END GENERATED` block. When
/// regeneration produces new generated content, ONLY the marked block
/// is replaced; everything above and below is preserved byte-for-byte.
///
/// If the target file exists WITHOUT markers AND has non-whitespace
/// content that differs from the new generated content, the merger
/// throws [ManualFileConflictException] — refusing to silently clobber
/// hand-written work (FR-009).
library;

/// Thrown when a manually-written file occupies the target path of a
/// generated tool file and the new content differs (FR-009).
class ManualFileConflictException implements Exception {
  const ManualFileConflictException(this.filePath);

  final String filePath;

  @override
  String toString() =>
      'ManualFileConflictException: "$filePath" already exists and has no '
      'GENERATED markers — refusing to silently overwrite manual work '
      '(FR-009). Either delete the file, rename it, or wrap its '
      'generated parts in `// GENERATED - DO NOT EDIT ... // END GENERATED` '
      'markers.';
}

/// Wraps generated content with `// GENERATED - DO NOT EDIT ... // END GENERATED`
/// markers so the merger can identify and safely replace it later.
const String kGeneratedStartMarker = '// GENERATED - DO NOT EDIT';
const String kGeneratedEndMarker = '// END GENERATED';

String wrapWithGeneratedMarkers(String content) {
  return '$kGeneratedStartMarker\n$content\n$kGeneratedEndMarker';
}

/// Merges [newGeneratedContent] into [existing] (if any), preserving
/// manual edits outside the GENERATED markers.
///
/// Returns the merged content. The [filePath] is used only for error
/// messages in [ManualFileConflictException].
///
/// Behavior:
/// 1. [existing] is null or empty → returns [newGeneratedContent]
///    wrapped with markers.
/// 2. [existing] does NOT contain [kGeneratedStartMarker] AND has
///    non-whitespace content → throws [ManualFileConflictException].
/// 3. [existing] DOES contain markers → replaces the marked block
///    (including the marker lines themselves) with the new generated
///    content (wrapped with fresh markers); preserves everything above
///    and below verbatim.
String mergeOrFresh({
  required String? existing,
  required String newGeneratedContent,
  required String filePath,
}) {
  if (existing == null || existing.trim().isEmpty) {
    return wrapWithGeneratedMarkers(newGeneratedContent);
  }

  final startIndex = existing.indexOf(kGeneratedStartMarker);
  if (startIndex == -1) {
    // No markers. If the existing content (when stripped of leading/trailing
    // whitespace and reformatted) matches the new generated content,
    // treat as idempotent re-write. Otherwise refuse.
    if (_normalizeWhitespace(existing) ==
        _normalizeWhitespace(newGeneratedContent)) {
      return wrapWithGeneratedMarkers(newGeneratedContent);
    }
    throw ManualFileConflictException(filePath);
  }

  final endIndex = existing.indexOf(kGeneratedEndMarker, startIndex);
  if (endIndex == -1) {
    // Start marker without end marker — corrupted. Treat as conflict.
    throw ManualFileConflictException(filePath);
  }

  // Find the line boundaries of the marker block so we don't leave
  // stray newlines.
  var blockStart = startIndex;
  // Walk back to the start of the line containing the start marker.
  while (blockStart > 0 && existing[blockStart - 1] != '\n') {
    blockStart--;
  }
  var blockEnd = endIndex + kGeneratedEndMarker.length;
  // Walk forward to the end of the line containing the end marker.
  while (blockEnd < existing.length && existing[blockEnd] != '\n') {
    blockEnd++;
  }
  // Consume the trailing newline if present, and remember whether the
  // original marker block had one — we'll re-emit exactly the same shape
  // to keep regeneration byte-for-byte idempotent (SC-003).
  final hadTrailingNewline =
      blockEnd < existing.length && existing[blockEnd] == '\n';
  if (hadTrailingNewline) {
    blockEnd++;
  }

  final before = existing.substring(0, blockStart);
  final after = existing.substring(blockEnd);
  final wrapped = wrapWithGeneratedMarkers(newGeneratedContent);

  // Compose: before + wrapped + (preserved trailing newline if any) + after.
  // We must NOT add a spurious trailing newline when the original had none;
  // that would break byte-for-byte idempotency (first pass produces no
  // trailing newline, second pass would add one — they'd differ).
  var composed = '';
  if (before.isNotEmpty) {
    composed += before;
    if (!before.endsWith('\n')) composed += '\n';
  }
  composed += wrapped;
  if (hadTrailingNewline) composed += '\n';
  if (after.isNotEmpty) {
    if (!after.startsWith('\n')) composed += '\n';
    composed += after;
  }
  return composed;
}

String _normalizeWhitespace(String s) {
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
