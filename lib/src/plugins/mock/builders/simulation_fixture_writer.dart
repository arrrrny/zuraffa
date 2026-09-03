/// Committed per-entity fixtures for the simulation flavor (spec 893,
/// T003; extends bug #832's fixture infrastructure).
///
/// `zfa mock create <entity> --fixtures-dir specs/<feature>/tdd/fixtures`
/// commits `<entity>_fixtures.json` with deterministic demo records
/// derived from the entity's fields, then re-certifies the fixtures
/// directory through the #832 [FixtureRegistry] (SHA-256 manifest +
/// hash-chained cycle evidence). The mock datasource consumes this
/// committed fixture data in simulation mode — no real network calls.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/string_utils.dart';
import 'simulation/fixture_certification.dart';

/// Writes and certifies per-entity fixture JSON.
class SimulationFixtureWriter {
  SimulationFixtureWriter({
    required this.outputDir,
    this.verbose = false,
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? const DefaultFileSystem();

  /// The generated project root (`lib/src`), used to locate the entity
  /// declaration the same way [EntityAnalyzer] does for mock data.
  final String outputDir;
  final bool verbose;
  final FileSystem fileSystem;

  static const int fixtureSchema = 1;
  static const int fixtureSpec = 893;

  /// Writes `<fixturesDir>/<entitySnake>_fixtures.json` and re-certifies
  /// the directory through the #832 registry. Returns the written
  /// [GeneratedFile] describing the fixture JSON.
  ///
  /// Unlike the hand-committed #832 certified worlds (which refuse
  /// overwrites without `--force`), per-entity fixture files are
  /// GENERATED artifacts — re-running `zfa mock create` rewrites and
  /// re-certifies them, exactly like the mock datasource itself. Byte
  /// drift outside the generator is still caught by the manifest's
  /// `verifyManifest` integrity check.
  Future<GeneratedFile> write({
    required String entityName,
    required String fixturesDir,
    String? commandLine,
  }) async {
    final entitySnake = StringUtils.camelToSnake(entityName);
    final fixtureFile = File(
      p.join(fixturesDir, '${entitySnake}_fixtures.json'),
    );

    final fields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );

    final fixture = <String, dynamic>{
      'schema': fixtureSchema,
      'spec': fixtureSpec,
      'entity': entityName,
      'fixture_source': 'lib/src/data/mock/${entitySnake}_mock_data.dart',
      'records': _records(fields, entitySnake),
    };

    Directory(fixturesDir).createSync(recursive: true);
    fixtureFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(fixture)}\n',
    );

    await certifyFixturesDirectory(
      fixturesDir,
      commandLine: commandLine ?? 'zfa mock create $entityName --fixtures-dir',
      verbose: verbose,
    );

    return GeneratedFile(
      path: fixtureFile.path,
      content: fixtureFile.readAsStringSync(),
      action: 'created',
      type: 'simulation_fixture',
    );
  }

  /// Deterministic demo records (three, matching the generated
  /// `<Entity>MockData` list size) derived from the analyzed entity
  /// fields. Values are JSON-serializable by construction.
  List<Map<String, dynamic>> _records(
    Map<String, String> fields,
    String entitySnake,
  ) {
    return List.generate(3, (i) {
      final seed = i + 1;
      return fields.map(
        (name, type) => MapEntry(name, _jsonValue(name, type, seed)),
      );
    });
  }

  Object? _jsonValue(String fieldName, String fieldType, int seed) {
    final isNullable = fieldType.endsWith('?');
    final baseType = fieldType.replaceAll('?', '');
    if (isNullable && seed % 3 == 0) return null;

    if (baseType.startsWith('List<')) return <dynamic>[];
    if (baseType.startsWith('Map<')) return <String, dynamic>{};

    switch (baseType) {
      case 'String':
        return 'fixture-$fieldName-$seed';
      case 'int':
        return seed;
      case 'double':
      case 'num':
        return seed + 0.5;
      case 'bool':
        return seed.isOdd;
      case 'DateTime':
        return '2026-09-0${seed.clamp(1, 9)}T00:00:00.000Z';
      default:
        // Nested entities, enums and other complex types carry a stable
        // placeholder so the fixture stays JSON-serializable while
        // keeping the record shape deterministic.
        return '$fieldName-$seed';
    }
  }
}
