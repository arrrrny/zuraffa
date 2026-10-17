import 'package:path/path.dart' as path;

import '../../core/context/file_system.dart';
import '../../utils/string_utils.dart';

/// Where a cache adapter's entity lives.
///
/// [isEnum] is true when the name resolves to a declaration under
/// `domain/entities/enums/`; [importPath] is the relative import the
/// regenerated registrar must carry for it.
typedef EntityLocation = ({bool isEnum, String importPath});

/// Resolves where [entityName] is declared, or null when nothing declares it.
///
/// The lookup order matches the historical cache-adapter scan:
/// `domain/entities/<snake>/<snake>.dart`, then `domain/entities/enums/index.dart`,
/// then `domain/entities/enums/<snake>.dart`. Enum declarations are matched
/// with a declaration boundary — `enum Status` must not match `enum
/// StatusCode` — because a false positive re-admits the
/// `spec.type.element == null` crash in `hive_ce_generator` (issue #1734).
///
/// Shared by `CacheBuilderRegistrar` and `CreateCacheAdapterCapability` so
/// both sides of a regeneration agree on which adapters exist.
Future<EntityLocation?> resolveCacheEntityLocation(
  String entityName, {
  required String outputDir,
  required FileSystem fileSystem,
}) async {
  final entitySnake = StringUtils.camelToSnake(entityName);
  final entityPath = path.join(
    outputDir,
    'domain',
    'entities',
    entitySnake,
    '$entitySnake.dart',
  );
  if (await fileSystem.exists(entityPath)) {
    return (
      isEnum: false,
      importPath: '../domain/entities/$entitySnake/$entitySnake.dart',
    );
  }

  final declaration = RegExp(
    'enum\\s+${RegExp.escape(entityName)}(?![A-Za-z0-9_])',
  );

  final enumIndexPath = path.join(
    outputDir,
    'domain',
    'entities',
    'enums',
    'index.dart',
  );
  if (await fileSystem.exists(enumIndexPath)) {
    final content = await fileSystem.read(enumIndexPath);
    if (declaration.hasMatch(content)) {
      return (isEnum: true, importPath: '../domain/entities/enums/index.dart');
    }
  }

  final enumFilePath = path.join(
    outputDir,
    'domain',
    'entities',
    'enums',
    '$entitySnake.dart',
  );
  if (await fileSystem.exists(enumFilePath)) {
    final content = await fileSystem.read(enumFilePath);
    if (declaration.hasMatch(content)) {
      return (
        isEnum: true,
        importPath: '../domain/entities/enums/$entitySnake.dart',
      );
    }
  }

  return null;
}
