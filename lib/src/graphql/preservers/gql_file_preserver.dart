import 'dart:io';

import 'package:gql/ast.dart' as ast;
import 'package:gql/language.dart' as gql_lang;
import 'package:zuraffa/zuraffa.dart';

/// Preserves existing `.graphql` files that are still valid against the schema.
///
/// When `zfa make Product --gql` runs:
/// 1. Check if the `.graphql` file already exists
/// 2. If yes, validate it against the cached schema
/// 3. If valid → **skip** (preserve user's edits)
/// 4. If invalid or missing → generate new file
/// 5. `--force` always overwrites
///
/// ```dart
/// final preserver = GqlFilePreserver(schema: schema);
/// final action = preserver.decide('get_product.graphql', newContent, force: false);
/// // action = Preserve | Overwrite | Generate
/// ```
class GqlFilePreserver {
  GqlFilePreserver({required this.schema});

  final GraphQLSchema schema;

  /// Decide what to do with a `.graphql` file.
  PreserverAction decide(
    String filePath,
    String newContent, {
    bool force = false,
  }) {
    final file = File(filePath);

    if (force) {
      return PreserverAction.overwrite;
    }

    if (!file.existsSync()) {
      return PreserverAction.generate;
    }

    final existingContent = file.readAsStringSync();

    // Check if file has UNVALIDATED header — always regenerate if schema is now available
    if (existingContent.contains('# UNVALIDATED')) {
      return PreserverAction.overwrite;
    }

    // Validate existing content against schema
    try {
      final validator = GraphQLValidator(schema: schema);
      final doc = _parseDocument(existingContent);
      final errors = validator.validate(doc);

      if (errors.where((e) => e.severity == ValidationSeverity.error).isEmpty) {
        return PreserverAction.preserve;
      }
    } catch (e) {
      // Parse error — treat as invalid
      return PreserverAction.overwrite;
    }

    return PreserverAction.overwrite;
  }

  /// Apply the decision and return the final content.
  String apply(String filePath, String newContent, {bool force = false}) {
    final action = decide(filePath, newContent, force: force);

    switch (action) {
      case PreserverAction.preserve:
        return File(filePath).readAsStringSync();
      case PreserverAction.overwrite:
      case PreserverAction.generate:
        return newContent;
    }
  }

  ast.DocumentNode _parseDocument(String content) {
    return gql_lang.parseString(content);
  }
}

enum PreserverAction {
  /// Keep the existing file (user edits preserved).
  preserve,

  /// Overwrite with generated content (invalid or --force).
  overwrite,

  /// Generate new file (did not exist).
  generate,
}
