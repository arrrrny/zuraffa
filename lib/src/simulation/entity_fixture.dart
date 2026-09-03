/// Committed per-entity fixture loading and boot-time validation (spec
/// 893, T003/T005; FR-009, SC-005).
///
/// `zfa mock create --fixtures-dir` commits `<entity>_fixtures.json`
/// under `specs/<feature>/tdd/fixtures/`. [EntityFixtures] loads those
/// records for the mock datasources at simulation boot; a missing or
/// corrupt fixture file fails the boot with a clear error naming the
/// entity — never a silent crash or blank screens.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Raised at simulation boot when an entity's committed fixtures are
/// missing or corrupt. The message always names the affected entity and
/// the fixture file path (FR-009).
final class SimulationFixtureError implements Exception {
  const SimulationFixtureError(this.entity, this.path, this.reason);

  final String entity;
  final String path;
  final String reason;

  @override
  String toString() =>
      'SimulationFixtureError: fixtures for entity "$entity" are unusable '
      '— $path: $reason. Re-run `zfa mock create $entity --fixtures-dir` '
      'to re-commit and re-certify them.';
}

/// Loads committed per-entity fixture records for simulation boot.
final class EntityFixtures {
  EntityFixtures._();

  /// The fixture file for [entity] inside [fixturesDir].
  static String pathFor({
    required String fixturesDir,
    required String entity,
  }) => p.join(fixturesDir, '${_snake(entity)}_fixtures.json');

  /// Loads the fixture records for every [entities] entry, failing fast
  /// with [SimulationFixtureError] on the first unusable file.
  ///
  /// Returns `{ entity -> records }`. Records are decoded fresh from the
  /// committed bytes on every call: the fixture files are the single
  /// source of truth for demo content.
  static Map<String, List<Map<String, dynamic>>> loadAll({
    required String fixturesDir,
    required Iterable<String> entities,
  }) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final entity in entities) {
      result[entity] = load(fixturesDir: fixturesDir, entity: entity);
    }
    return result;
  }

  /// Loads the fixture records for [entity], failing fast.
  static List<Map<String, dynamic>> load({
    required String fixturesDir,
    required String entity,
  }) {
    final file = File(pathFor(fixturesDir: fixturesDir, entity: entity));
    if (!file.existsSync()) {
      throw SimulationFixtureError(
        entity,
        file.path,
        'fixture file is missing',
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      throw SimulationFixtureError(
        entity,
        file.path,
        'fixture is not valid JSON: $e',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw SimulationFixtureError(
        entity,
        file.path,
        'fixture is not a JSON object',
      );
    }
    final records = decoded['records'];
    if (records is! List) {
      throw SimulationFixtureError(
        entity,
        file.path,
        'fixture has no records list',
      );
    }
    for (final record in records) {
      if (record is! Map<String, dynamic>) {
        throw SimulationFixtureError(
          entity,
          file.path,
          'fixture records must be JSON objects',
        );
      }
    }
    return records.cast<Map<String, dynamic>>();
  }

  static String _snake(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final char = name[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (isUpper && i > 0) buffer.write('_');
      buffer.write(char.toLowerCase());
    }
    return buffer.toString();
  }
}
