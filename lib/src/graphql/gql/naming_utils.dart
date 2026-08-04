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
  /// 2. Replace all non-alphanumeric characters (including `.`, `_`,
  ///    `-`, spaces) with `_`, then split on `_`.
  /// 3. For a single segment: lowercase only the first character,
  ///    preserving internal casing. For multiple segments: fully
  ///    lowercase the first segment; title-case every subsequent
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
  /// NamingUtils.documentVarName('get.todo.graphql') // 'getTodo'
  /// NamingUtils.documentVarName('MyHTTPServer')   // 'myHTTPServer'
  /// ```
  static String documentVarName(String fileName) {
    // 1. Strip .graphql extension
    var base = fileName;
    if (base.endsWith('.graphql')) {
      base = base.substring(0, base.length - 7);
    }

    // 2. Replace all non-alphanumeric characters with underscores, split
    final normalized = base.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final parts = normalized.split('_').where((s) => s.isNotEmpty).toList();

    if (parts.isEmpty) return '';

    // 3. First segment: lowercase first char only; rest: title-case
    final buffer = StringBuffer();
    if (parts.length == 1) {
      // Single segment: lowercase only the first character, preserve rest
      final first = parts[0];
      if (first.isNotEmpty) {
        buffer.write(first[0].toLowerCase());
        if (first.length > 1) {
          buffer.write(first.substring(1));
        }
      }
    } else {
      // Multiple segments: fully lowercase first, title-case rest
      buffer.write(parts[0].toLowerCase());
      for (var i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;
        buffer.write(part[0].toUpperCase());
        if (part.length > 1) {
          buffer.write(part.substring(1).toLowerCase());
        }
      }
    }

    return buffer.toString();
  }
}
