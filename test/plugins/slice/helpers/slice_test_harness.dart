/// Shared harness for fixture-backed slice tests (T123).
///
/// Every `test/plugins/slice/**` test that drives `SliceCommand` against the
/// fixture project copies the committed fixture into a fresh temp directory
/// in `setUp` and removes it in `tearDown`. This helper is that pair, so
/// the boilerplate is not copy-pasted per file.
library;

import 'dart:io';

import 'copy_fixture_project.dart';

/// Creates a fresh copy of the slice fixture project for one test.
///
/// Register the companion cleanup:
/// ```dart
/// late String projectRoot;
/// setUp(() async => projectRoot = await freshSliceProject());
/// tearDown(() => disposeSliceProject(projectRoot));
/// ```
Future<String> freshSliceProject() => copySliceFixtureProject();

/// Removes the fixture copy created by [freshSliceProject].
Future<void> disposeSliceProject(String projectRoot) async {
  final dir = Directory(projectRoot);
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
