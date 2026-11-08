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
///
/// The copy is hermetic: any `.dart_tool/` in the source tree is dropped
/// and a minimal RELATIVE `package_config.json` is synthesized in its
/// place. The walker's PackageResolver needs only the self package
/// (`zik_zak` at `../`) — every other package is external and never
/// traversed — so committing one host's resolved 63-package config (its
/// absolute `/home/<user>/...` rootUris) is neither needed nor wanted.
Future<String> copySliceFixtureProject() async {
  final dest = await Directory.systemTemp.createTemp('slice_fixture_');
  await _copyDir(Directory(sliceFixtureSource), Directory(dest.path));
  final copiedTool = Directory(p.join(dest.path, '.dart_tool'));
  if (copiedTool.existsSync()) {
    await copiedTool.delete(recursive: true);
  }
  _writeRelativePackageConfig(dest.path);
  return dest.path;
}

/// Writes the minimal relative package config the resolver needs: the
/// self package at the project root (`../` against `.dart_tool/`).
void _writeRelativePackageConfig(String projectRoot) {
  final toolDir = Directory(p.join(projectRoot, '.dart_tool'));
  toolDir.createSync(recursive: true);
  File(
    p.join(toolDir.path, 'package_config.json'),
  ).writeAsStringSync(_relativePackageConfig);
}

/// Minimal relative package config: only the self package, rooted at the
/// copy's own directory. External packages classify by name and are never
/// traversed, so no real dependency needs an entry.
const _relativePackageConfig = '''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "zik_zak",
      "rootUri": "../",
      "packageUri": "lib/",
      "languageVersion": "3.11"
    }
  ],
  "generator": "zuraffa-test-harness"
}
''';

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
