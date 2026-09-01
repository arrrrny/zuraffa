// SPDX-License-Identifier: MIT
//
// BrandingWriter tests — spec 053-zuraffa-branding

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/branding/branding_writer.dart';

/// The zuraffa repo root — hardcoded for test reliability under dart test's
/// cached kernel path (Platform.script resolves to /var/folders/...).
const _zuraffaRoot = '/Users/ahmettok/Developer/zuraffa';

void main() {
  group('BrandingWriter', () {
    group('writeFlutterBranding', () {
      test(
        'copies assets/zuraffa_app_icons/ to target project assets/ directory',
        () async {
          // Arrange: create a temp Flutter project structure
          final tmp = await Directory.systemTemp.createTemp('branding_test_');
          addTearDown(() => tmp.deleteSync(recursive: true));

          final projectRoot = p.join(tmp.path, 'my_app');
          Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);

          final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);

          // Act
          await writer.writeFlutterBranding(
            projectRoot: projectRoot,
            dryRun: false,
            verbose: false,
          );

          // Assert: assets/zuraffa_app_icons/ exists and is not empty
          final dest = Directory(p.join(projectRoot, 'assets', 'zuraffa_app_icons'));
          expect(dest.existsSync(), isTrue, reason: 'assets/zuraffa_app_icons/ should be created');
          final files = dest.listSync().whereType<File>().toList();
          expect(files.isNotEmpty, isTrue, reason: 'assets/zuraffa_app_icons/ should contain files');
        },
      );
    });
  });
}
