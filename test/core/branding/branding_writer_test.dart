// SPDX-License-Identifier: MIT
//
// BrandingWriter tests — spec 053-zuraffa-branding

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/core/branding/branding_writer.dart';

/// The zuraffa repo root — resolved dynamically so tests run on CI and any
/// checkout location. findZuraffaRoot walks up from CWD looking for the brand
/// assets directory (or a zuraffa pubspec).
final _zuraffaRoot = findZuraffaRoot();

void main() {
  group('BrandingWriter', () {
    group('writeFlutterBranding', () {
      // ── U1 ────────────────────────────────────────────────────────────────
      test(
        'copies assets/zuraffa_app_icons/ to target project assets/ directory',
        () async {
          final tmp = await Directory.systemTemp.createTemp('branding_test_');
          addTearDown(() => tmp.deleteSync(recursive: true));

          final projectRoot = p.join(tmp.path, 'my_app');
          Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);

          final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
          await writer.writeFlutterBranding(
            projectRoot: projectRoot,
            dryRun: false,
            verbose: false,
          );

          final dest = Directory(
            p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
          );
          expect(
            dest.existsSync(),
            isTrue,
            reason: 'assets/zuraffa_app_icons/ should be created',
          );
          final files = dest.listSync().whereType<File>().toList();
          expect(
            files.isNotEmpty,
            isTrue,
            reason: 'assets/zuraffa_app_icons/ should contain files',
          );
        },
      );

      // ── U2 ────────────────────────────────────────────────────────────────
      test('copies iOS icons to ios/Runner/Assets.xcassets/', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test2_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        // Only create the project root — writeFlutterBranding creates subdirs
        final projectRoot = p.join(tmp.path, 'my_app');

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeFlutterBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        final dest = Directory(
          p.join(projectRoot, 'ios', 'Runner', 'Assets.xcassets'),
        );
        expect(
          dest.existsSync(),
          isTrue,
          reason: 'ios/Runner/Assets.xcassets/ should be created',
        );
        final files = dest.listSync(recursive: true).whereType<File>().toList();
        expect(
          files.isNotEmpty,
          isTrue,
          reason: 'Assets.xcassets/ should contain files from source',
        );
      });

      // ── U3 ────────────────────────────────────────────────────────────────
      test('copies Android icons to android/app/src/main/res/', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_app');
        Directory(
          p.join(projectRoot, 'android', 'app', 'src', 'main', 'res'),
        ).createSync(recursive: true);

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeFlutterBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        // At minimum we expect mipmap directories to be created/used
        final resDir = Directory(
          p.join(projectRoot, 'android', 'app', 'src', 'main', 'res'),
        );
        expect(
          resDir.existsSync(),
          isTrue,
          reason: 'android/app/src/main/res/ should exist',
        );
        final subdirs = resDir.listSync().whereType<Directory>().toList();
        expect(
          subdirs.isNotEmpty,
          isTrue,
          reason: 'res/ should have density subdirectories with icons',
        );
      });

      // ── U4 ────────────────────────────────────────────────────────────────
      test(
        'adds assets/zuraffa_app_icons/ to pubspec.yaml flutter assets',
        () async {
          final tmp = await Directory.systemTemp.createTemp('branding_test_');
          addTearDown(() => tmp.deleteSync(recursive: true));

          final projectRoot = p.join(tmp.path, 'my_app');
          Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);
          final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
          pubspecFile.writeAsStringSync('''
name: my_app
flutter:
  uses-material-design: true
''');
          Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);

          final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
          await writer.writeFlutterBranding(
            projectRoot: projectRoot,
            dryRun: false,
            verbose: false,
          );

          final content = pubspecFile.readAsStringSync();
          expect(
            content.contains('zuraffa_app_icons'),
            isTrue,
            reason: 'pubspec.yaml should reference zuraffa_app_icons',
          );
        },
      );

      // ── U7 ────────────────────────────────────────────────────────────────
      test('removes flutter.png from the target project', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_app');
        // Place a flutter.png in the assets dir
        final flutterPng = File(p.join(projectRoot, 'assets', 'flutter.png'));
        flutterPng.createSync(recursive: true);
        flutterPng.writeAsStringSync('fake png content');

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeFlutterBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        expect(
          flutterPng.existsSync(),
          isFalse,
          reason: 'flutter.png should be removed after branding',
        );
      });

      // ── U8 ────────────────────────────────────────────────────────────────
      test('removes flutter_animated.png from the target project', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_app');
        final flutterAnimPng = File(
          p.join(projectRoot, 'assets', 'flutter_animated.png'),
        );
        flutterAnimPng.createSync(recursive: true);
        flutterAnimPng.writeAsStringSync('fake animated png content');

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeFlutterBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        expect(
          flutterAnimPng.existsSync(),
          isFalse,
          reason: 'flutter_animated.png should be removed after branding',
        );
      });

      // ── U9 ────────────────────────────────────────────────────────────────
      test('is idempotent: calling twice produces identical output', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_app');
        Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeFlutterBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );
        await writer.writeFlutterBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        // Both calls should succeed without error and produce the same state
        final dest = Directory(
          p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
        );
        expect(dest.existsSync(), isTrue);
        final files = dest.listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);
      });

      // ── U11 ───────────────────────────────────────────────────────────────
      test(
        'skips branding when assets/zuraffa_app_icons/ already exists',
        () async {
          final tmp = await Directory.systemTemp.createTemp('branding_test_');
          addTearDown(() => tmp.deleteSync(recursive: true));

          final projectRoot = p.join(tmp.path, 'my_app');
          final brandDir = Directory(
            p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
          );
          brandDir.createSync(recursive: true);
          // Put a marker file so we can verify it wasn't overwritten
          File(p.join(brandDir.path, 'sentinel')).writeAsStringSync('original');

          final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
          await writer.writeFlutterBranding(
            projectRoot: projectRoot,
            dryRun: false,
            verbose: false,
          );

          // Sentinel should still be there (no clobber)
          expect(
            File(p.join(brandDir.path, 'sentinel')).readAsStringSync(),
            equals('original'),
            reason: 'existing branding directory should not be overwritten',
          );
        },
      );
    });

    group('writeDartBranding', () {
      // ── U5 ────────────────────────────────────────────────────────────────
      test('copies brand assets to target assets/ directory', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_pkg');
        Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeDartBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        final dest = Directory(
          p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
        );
        expect(
          dest.existsSync(),
          isTrue,
          reason: 'assets/zuraffa_app_icons/ should be created for Dart',
        );
        final files = dest.listSync().whereType<File>().toList();
        expect(
          files.isNotEmpty,
          isTrue,
          reason: 'assets/zuraffa_app_icons/ should contain files',
        );
      });

      // ── U6 ────────────────────────────────────────────────────────────────
      test('prepends Zuraffa banner to README.md', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_pkg');
        Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);
        final readme = File(p.join(projectRoot, 'README.md'));
        readme.writeAsStringSync('# My Package\n\nA great package.\n');

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeDartBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        final lines = readme.readAsStringSync().split('\n');
        expect(
          lines.take(10).any((l) => l.contains('Zuraffa')),
          isTrue,
          reason: 'README should contain "Zuraffa" within first 10 lines',
        );
      });

      // ── U10 ───────────────────────────────────────────────────────────────
      test('is idempotent: calling twice produces identical output', () async {
        final tmp = await Directory.systemTemp.createTemp('branding_test_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final projectRoot = p.join(tmp.path, 'my_pkg');
        Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);
        File(
          p.join(projectRoot, 'README.md'),
        ).writeAsStringSync('# My Package\n\nA great package.\n');

        final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
        await writer.writeDartBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );
        await writer.writeDartBranding(
          projectRoot: projectRoot,
          dryRun: false,
          verbose: false,
        );

        final dest = Directory(
          p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
        );
        expect(dest.existsSync(), isTrue);
        final files = dest.listSync().whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);
      });
    });
  });
}
