/// Shared test helper: copies a fixture directory into a temp specs root.
///
/// Used by bone_generator_test.dart, sc_002.
library;

import 'dart:io';

/// Copies [fixtureName] from `test/plugins/skeleton/fixtures/` into [destParent].
///
/// Only copies files (not subdirectories) to match the original behavior.
Future<void> copyFixture(String fixtureName, String destParent) async {
  final src = Directory('test/plugins/skeleton/fixtures/$fixtureName');
  final dest = await Directory(
    '$destParent/$fixtureName',
  ).create(recursive: true);
  for (final entity in src.listSync()) {
    if (entity is File) {
      await entity.copy('${dest.path}/${entity.uri.pathSegments.last}');
    }
  }
}
