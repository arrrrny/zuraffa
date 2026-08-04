import 'dart:io';

import 'package:path/path.dart' as p;

import '../migration_models.dart';
import 'base_fixer.dart';

class GqlMigrator extends MigrationFixer {
  @override
  String get migratorId => 'v5_gql_const_string';

  @override
  String get displayName => 'GQL: v5 const-string to .graphql files';

  @override
  Future<MigrationResult> migrate({
    required List<MigrationFinding> findings,
    required String projectDir,
    bool dryRun = false,
  }) async {
    final actions = <MigrationAction>[];
    final remaining = <MigrationFinding>[];

    // Deduplicate findings by filePath
    final findingsByFile = <String, MigrationFinding>{};
    for (final finding in findings) {
      if (finding.ruleId != 'v5_gql_const_string') {
        remaining.add(finding);
        continue;
      }
      findingsByFile[finding.filePath] = finding;
    }

    for (final finding in findingsByFile.values) {
      final filePath = p.join(projectDir, finding.filePath);
      if (!File(filePath).existsSync()) {
        remaining.add(finding);
        continue;
      }

      final content = File(filePath).readAsStringSync();

      // Check if already migrated
      if (content.startsWith(
        '// NOTE: GraphQL documents have been migrated to .graphql files.',
      )) {
        continue;
      }

      final extracted = _extractGqlDocuments(content);
      if (extracted.isEmpty) {
        remaining.add(finding);
        continue;
      }

      final fileDir = p.dirname(filePath);
      final graphqlDir = p.join(fileDir, 'graphql');

      final usedNames = <String>{};
      for (final doc in extracted) {
        var opName = doc.operationName.toLowerCase();
        var targetName = opName;
        var counter = 1;

        // Detect collisions and choose unique name
        while (usedNames.contains(targetName) ||
            File(p.join(graphqlDir, '$targetName.graphql')).existsSync()) {
          targetName = '${opName}_$counter';
          counter++;
        }
        usedNames.add(targetName);

        final graphqlPath = p.join(graphqlDir, '$targetName.graphql');
        actions.add(
          MigrationAction(
            description: 'Extract $targetName to .graphql file',
            filePath: graphqlPath,
            action: 'created',
            newContent: doc.content,
          ),
        );
        if (!dryRun) {
          Directory(graphqlDir).createSync(recursive: true);
          File(graphqlPath).writeAsStringSync(doc.content);
        }
      }

      final header =
          '// NOTE: GraphQL documents have been migrated to .graphql files.\n'
          '// Run zfa build to regenerate documents.dart.\n\n';
      final newContent = header + content;

      if (!dryRun) {
        File(filePath).writeAsStringSync(newContent);
      }

      actions.add(
        MigrationAction(
          description: 'Annotate ${finding.filePath} with migration notice',
          filePath: filePath,
          action: 'modified',
          originalContent: content,
          newContent: newContent,
        ),
      );
    }

    return MigrationResult(
      migratorId: migratorId,
      actions: actions,
      remaining: remaining,
    );
  }

  List<_GqlDoc> _extractGqlDocuments(String content) {
    final docs = <_GqlDoc>[];
    // Match gql( calls with triple-quoted string arguments
    final startPattern = RegExp(r'gql\s*\(');

    for (final startMatch in startPattern.allMatches(content)) {
      final afterStart = startMatch.end;
      // Look for optional whitespace and optional 'r' prefix before quotes
      final remaining = content.substring(afterStart);
      final quotePattern = RegExp("^\\s*(r)?\\s*('''|\"\"\")");
      final quoteMatch = quotePattern.firstMatch(remaining);

      if (quoteMatch == null) continue;

      final quoteStr = quoteMatch.group(2)!; // ''' or """
      final bodyStart = afterStart + quoteMatch.end;

      // Find closing triple quote
      final endPattern = RegExp(RegExp.escape(quoteStr));
      final endMatch = endPattern.firstMatch(content.substring(bodyStart));
      if (endMatch == null) continue;

      final body = content
          .substring(bodyStart, bodyStart + endMatch.start)
          .trim();
      final opName = _extractOperationName(body);
      if (opName != null) {
        docs.add(_GqlDoc(operationName: opName, content: body));
      }
    }

    return docs;
  }

  String? _extractOperationName(String body) {
    final match = RegExp(
      r'(?:query|mutation|subscription)\s+(\w+)',
    ).firstMatch(body);
    return match?.group(1);
  }
}

class _GqlDoc {
  final String operationName;
  final String content;
  const _GqlDoc({required this.operationName, required this.content});
}
