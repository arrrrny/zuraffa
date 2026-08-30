/// Shared test helper: copies the slice fixture project into a temp directory.
///
/// Tests operate on the copy so sandbox creation never dirties the repo's
/// fixture tree.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Source of the committed fixture (relative to the repo root).
const sliceFixtureSource = 'test/fixtures/slice_test_project';

/// Copies the fixture project into a fresh temp directory and returns its
/// absolute path.
Future<String> copySliceFixtureProject() async {
  final dest = await Directory.systemTemp.createTemp('slice_fixture_');
  await _copyDir(Directory(sliceFixtureSource), Directory(dest.path));
  return dest.path;
}

Future<void> _copyDir(Directory src, Directory dest) async {
  await dest.create(recursive: true);
  for (final entity in src.listSync(recursive: false)) {
    final targetPath = p.join(dest.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDir(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}
