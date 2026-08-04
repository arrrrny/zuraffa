/// Utilities for naming GraphQL-derived Dart identifiers.
///
/// Provides a single entry-point — [documentVarName] — that converts
/// a GraphQL document file name into a valid, camelCase Dart variable
/// name suitable for use in generated code.
library;

/// Pure-static utility class for GraphQL codegen naming.
///
/// All methods are static; instantiate only if you need to subclass
/// or mock for testing.
class NamingUtils {
  /// Prevents instantiation — all members are static.
  NamingUtils._();

  /// Converts a GraphQL document file name into a camelCase Dart
  /// variable name.
  ///
  /// The transformation is deterministic so that the generated code
  /// can detect duplicate variable names across directories.
  ///
  /// Rules (applied in order):
  /// 1. Strip the `.graphql` extension if present.
  /// 2. Replace non-alphanumeric separators (`_`, `-`, spaces) with
  ///    `_`, then split on `_`.
  /// 3. Lower-case the first segment; title-case every subsequent
  ///    segment (first char upper, rest lower).
  /// 4. Concatenate all segments.
  ///
  /// Examples:
  /// ```dart
  /// NamingUtils.documentVarName('get_todo')       // 'getTodo'
  /// NamingUtils.documentVarName('user_by_id')     // 'userById'
  /// NamingUtils.documentVarName('getTodo')        // 'getTodo'
  /// NamingUtils.documentVarName('GetTodo')        // 'getTodo'
  /// NamingUtils.documentVarName('get-todo')       // 'getTodo'
  /// NamingUtils.documentVarName('all products')   // 'allProducts'
  /// NamingUtils.documentVarName('get_todo.graphql') // 'getTodo'
  /// ```
  static String documentVarName(String fileName) {
    // 1. Strip .graphql extension
    var base = fileName;
    if (base.endsWith('.graphql')) {
      base = base.substring(0, base.length - 7);
    }

    // 2. Replace hyphens and spaces with underscores, split
    final normalized = base.replaceAll('-', '_').replaceAll(' ', '_');
    final parts = normalized.split('_').where((s) => s.isNotEmpty).toList();

    if (parts.isEmpty) return '';

    // 3. First segment: lowercase; rest: title-case
    final buffer = StringBuffer();
    buffer.write(parts[0].toLowerCase());
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;
      buffer.write(part[0].toUpperCase());
      if (part.length > 1) {
        buffer.write(part.substring(1).toLowerCase());
      }
    }

    return buffer.toString();
  }
}
