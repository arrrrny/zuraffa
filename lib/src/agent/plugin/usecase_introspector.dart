/// UseCase introspection (FR-004).
///
/// Walks `lib/src/domain/usecases/{domain}/` for files matching
/// `*_{entitySnake}_usecase.dart` and extracts [UseCaseMetadata]
/// records. The extractor uses a regex-based parser rather than the
/// analyzer AST because generated UseCase files have a highly regular
/// shape (`class CreateXUseCase extends UseCase<X, Y> { ... }`),
/// regex keeps the plugin robust against analyzer API version
/// migrations, and the introspection surface is read-only metadata
/// extraction (no semantic resolution needed).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// A single field on a UseCase's Params type.
class ParamField {
  final String name;
  final String type;
  final bool isRequired;

  const ParamField({
    required this.name,
    required this.type,
    required this.isRequired,
  });

  @override
  String toString() => 'ParamField($name: $type${isRequired ? '' : '?'})';
}

/// Metadata extracted from a single generated UseCase file.
class UseCaseMetadata {
  final String className;
  final String paramsType;
  final List<ParamField> paramsFields;
  final String returnType;
  final String verb;
  final bool isAgentInternal;
  final String sourcePath;

  const UseCaseMetadata({
    required this.className,
    required this.paramsType,
    required this.paramsFields,
    required this.returnType,
    required this.verb,
    required this.isAgentInternal,
    required this.sourcePath,
  });

  @override
  String toString() =>
      'UseCaseMetadata($className → $verb, '
      'params=$paramsType, return=$returnType, '
      'internal=$isAgentInternal)';
}

/// Walks an entity's generated UseCase directory and produces
/// [UseCaseMetadata] records.
class UseCaseIntrospector {
  final String projectRoot;

  const UseCaseIntrospector({required this.projectRoot});

  /// Introspects [entityName]'s usecase directory and returns one
  /// [UseCaseMetadata] per usecase file.
  ///
  /// The directory scanned is `lib/src/domain/usecases/{entitySnake}/`.
  /// Files matching `*_{entitySnake}_usecase.dart` are parsed.
  ///
  /// Returns an empty list (and prints an informational message) if no
  /// files match — this is NOT an error condition (Edge Case: "Entity
  /// with no UseCases").
  Future<List<UseCaseMetadata>> introspect(String entityName) async {
    final entitySnake = _toSnake(entityName);
    final usecaseDir = p.join(
      projectRoot,
      'lib',
      'src',
      'domain',
      'usecases',
      entitySnake,
    );

    final dir = Directory(usecaseDir);
    if (!dir.existsSync()) {
      // ignore: avoid_print
      print(
        'ℹ️  AgentPlugin: no usecase directory at $usecaseDir for entity '
        '"$entityName" — no MCP tool wrappers will be generated.',
      );
      return const <UseCaseMetadata>[];
    }

    final results = <UseCaseMetadata>[];
    final entities = dir.listSync();
    for (final entity in entities) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // Only consider usecase files. The entity scoping is already
      // enforced by the parent directory `usecases/{entitySnake}/`,
      // so we do NOT additionally require `{entitySnake}_usecase.dart` —
      // this would exclude legitimate multi-segment filenames such as
      // `get_listing_list_usecase.dart` (FR-004 regression).
      if (!name.endsWith('_usecase.dart')) continue;
      final content = entity.readAsStringSync();
      final metadata = _parseContent(content, entity.path);
      if (metadata != null) {
        results.add(metadata);
      }
    }

    if (results.isEmpty) {
      // ignore: avoid_print
      print(
        'ℹ️  AgentPlugin: entity "$entityName" has no generated UseCase '
        'files at $usecaseDir — no MCP tool wrappers will be generated.',
      );
    }
    return results;
  }

  /// Parses the content of a single UseCase file. Exposed for testing.
  UseCaseMetadata? parseContent(String content, String filePath) {
    return _parseContent(content, filePath);
  }

  UseCaseMetadata? _parseContent(String content, String filePath) {
    // Find the class declaration that extends UseCase<...>.
    //
    // Match: `class CreateListingUseCase extends UseCase<Listing, Listing> {`
    //
    // We deliberately stop the regex at the opening `<` and then scan for the
    // matching `>` with a balanced-bracket walk. A naive `[^>]+>` regex
    // would stop at the first `>` it sees — for `UseCase<List<Listing>,
    // ListQueryParams<Listing>>` that first `>` is the inner one inside
    // `List<Listing>`, truncating the captured type args and producing
    // broken metadata. The balanced walk correctly handles arbitrary
    // nesting depth (FR-004).
    final clsPattern = RegExp(
      r'class\s+(\w+)\s+extends\s+(UseCase|StreamUseCase|CompletableUseCase)\s*<',
    );
    final match = clsPattern.firstMatch(content);
    if (match == null) return null;

    final className = match.group(1)!;
    final typeArgsRaw = _extractBalancedAngle(content, match.end);
    if (typeArgsRaw == null) return null;
    final typeArgs = typeArgsRaw.trim();
    final parts = _splitTopLevelCommas(typeArgs);
    final returnTypeStr = parts.isNotEmpty ? parts[0].trim() : 'dynamic';
    final paramsTypeStr = parts.length >= 2 ? parts[1].trim() : 'dynamic';

    final verb = _deriveVerb(className);
    final isAgentInternal = content.contains('@AgentInternal');

    // Params fields: we can't easily extract these without resolving the
    // Params type from another file. For the common case where the
    // Params type is the entity itself, we leave paramsFields empty
    // and the schema deriver will fall back to an open-object schema
    // for the entity (which is then a "best-effort" schema — the runtime
    // MCP client can send arbitrary fields and the UseCase will see them).
    // For tests with fixture data, callers can construct UseCaseMetadata
    // directly with populated paramsFields.
    final paramsFields = <ParamField>[];

    return UseCaseMetadata(
      className: className,
      paramsType: paramsTypeStr,
      paramsFields: paramsFields,
      returnType: returnTypeStr,
      verb: verb,
      isAgentInternal: isAgentInternal,
      sourcePath: p.relative(filePath, from: projectRoot),
    );
  }

  /// Walks [content] from [start] until the angle-bracket opened just
  /// before [start] is closed. Returns the substring between (exclusive
  /// of the closing `>`), or null if unbalanced before end-of-string.
  ///
  /// Handles nested generics like `List<List<Listing>>` correctly.
  String? _extractBalancedAngle(String content, int start) {
    var depth = 1;
    var i = start;
    for (; i < content.length; i++) {
      final c = content[i];
      if (c == '<') {
        depth++;
      } else if (c == '>') {
        depth--;
        if (depth == 0) {
          return content.substring(start, i);
        }
      }
    }
    return null;
  }

  /// Derives the verb from a UseCase class name.
  ///
  /// `CreateListingUseCase` → `create`
  /// `GetListingUseCase` → `get`
  /// `GetListingListUseCase` → `list`
  /// `DeleteListingUseCase` → `delete`
  /// `UpdateListingUseCase` → `update`
  /// `WatchListingUseCase` → `watch`
  ///
  /// The `List` suffix after the entity name (as in `Get{Entity}ListUseCase`)
  /// is the canonical Zuraffa list-fetching convention and is detected
  /// BEFORE the verb-prefix check, so `Get*List*UseCase` derives to `list`
  /// rather than `get`.
  String _deriveVerb(String className) {
    var s = className;
    if (s.endsWith('UseCase')) {
      s = s.substring(0, s.length - 'UseCase'.length);
    }
    // List-fetch convention: `Get{Entity}ListUseCase` → `list`.
    if (s.endsWith('List')) {
      return 'list';
    }
    const knownVerbs = {
      'create',
      'update',
      'delete',
      'get',
      'list',
      'watch',
      'toggle',
    };
    for (final v in knownVerbs) {
      if (s.toLowerCase().startsWith(v)) {
        return v;
      }
    }
    if (s.isEmpty) return 'call';
    return s[0].toLowerCase() + s.substring(1);
  }

  String _toSnake(String s) {
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c.toUpperCase() == c && c.toLowerCase() != c) {
        if (i > 0) buf.write('_');
        buf.write(c.toLowerCase());
      } else {
        buf.write(c);
      }
    }
    return buf.toString().toLowerCase();
  }

  /// Splits a comma-separated type-args string on top-level commas
  /// (ignoring commas inside nested generics).
  static List<String> _splitTopLevelCommas(String s) {
    final parts = <String>[];
    var depth = 0;
    final buf = StringBuffer();
    for (final c in s.runes) {
      final ch = String.fromCharCode(c);
      if (ch == '<' || ch == '[' || ch == '(') {
        depth++;
        buf.write(ch);
      } else if (ch == '>' || ch == ']' || ch == ')') {
        depth--;
        buf.write(ch);
      } else if (ch == ',' && depth == 0) {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }
}
