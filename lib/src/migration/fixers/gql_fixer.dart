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

    for (final finding in findings) {
      if (finding.ruleId != 'v5_gql_const_string') {
        remaining.add(finding);
        continue;
      }

      final filePath = p.join(projectDir, finding.filePath);
      if (!File(filePath).existsSync()) {
        remaining.add(finding);
        continue;
      }

      final content = File(filePath).readAsStringSync();
      final extracted = _extractGqlDocuments(content);
      if (extracted.isEmpty) {
        remaining.add(finding);
        continue;
      }

      final fileDir = p.dirname(filePath);
      final graphqlDir = p.join(fileDir, 'graphql');

      for (final doc in extracted) {
        final opName = doc.operationName.toLowerCase();
        final graphqlPath = p.join(graphqlDir, opName + '.graphql');
        actions.add(MigrationAction(
          description: 'Extract ' + opName + ' to .graphql file',
          filePath: graphqlPath,
          action: 'created',
          newContent: doc.content,
        ));
        if (!dryRun) {
          Directory(graphqlDir).createSync(recursive: true);
          File(graphqlPath).writeAsStringSync(doc.content);
        }
      }

      if (!dryRun) {
        final header =
            '// NOTE: GraphQL documents have been migrated to .graphql files.\n'
            '// Run zfa build to regenerate documents.dart.\n\n';
        File(filePath).writeAsStringSync(header + content);
      }

      actions.add(MigrationAction(
        description: 'Annotate ' + finding.filePath + ' with migration notice',
        filePath: filePath,
        action: 'modified',
        originalContent: content,
      ));
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
    final startPattern = RegExp('gql\\s*\\(');
    final singleQuote3 = RegExp("'''");
    final doubleQuote3 = RegExp('"""');

    for (final startMatch in startPattern.allMatches(content)) {
      final afterStart = startMatch.end;
      // Determine which quote style is used
      final remaining = content.substring(afterStart);
      String? quoteStr;
      int quoteStart = -1;
      final sq = singleQuote3.firstMatch(remaining);
      final dq = doubleQuote3.firstMatch(remaining);
      if (sq != null && (dq == null || sq.start <= dq.start)) {
        quoteStr = "'''";
        quoteStart = sq.start;
      } else if (dq != null) {
        quoteStr = '"""';
        quoteStart = dq.start;
      }
      if (quoteStr == null) continue;

      final bodyStart = afterStart + quoteStart + 3;
      final endPattern = RegExp(quoteStr);
      final endMatch = endPattern.firstMatch(content.substring(bodyStart));
      if (endMatch == null) continue;

      final body = content.substring(bodyStart, bodyStart + endMatch.start).trim();
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
