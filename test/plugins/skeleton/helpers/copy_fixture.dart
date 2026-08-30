/// Shared test helper: copies a fixture directory into a temp specs root.
///
/// Used by bone_generator_test.dart, sc_002.
library;

import 'dart:io';

import '../../../helpers/project_root.dart';

/// Copies [fixtureName] from `test/plugins/skeleton/fixtures/` into [destParent].
///
/// Only copies files (not subdirectories) to match the original behavior.
Future<void> copyFixture(String fixtureName, String destParent) async {
  // Resolve via package URI so this helper is immune to CWD pollution when
  // other test files concurrently change Directory.current.
  final root = await findProjectRoot();
  final src = Directory('$root/test/plugins/skeleton/fixtures/$fixtureName');
  final dest = await Directory(
    '$destParent/$fixtureName',
  ).create(recursive: true);
  for (final entity in src.listSync()) {
    if (entity is File) {
      await entity.copy('${dest.path}/${entity.uri.pathSegments.last}');
    }
  }
}
