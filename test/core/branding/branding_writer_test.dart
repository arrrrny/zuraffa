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

/// Whether the brand asset source directory exists. On CI and minimal clones
/// the assets may not be checked out; tests that need real assets skip
/// themselves in that case so the suite stays green.
final _brandAssetsExist = Directory(
  p.join(_zuraffaRoot, 'assets', 'zuraffa_app_icons'),
).existsSync();

void main() {
  group('BrandingWriter', () {
    group('writeFlutterBranding', () {
      // Issue found live (zik_zak migration): a target pubspec that
      // ALREADY has `flutter: assets:` must get the icon entry MERGED
      // into that list — a second `assets:` key is a duplicate mapping
      // key that makes the whole pubspec unparseable.
      test(
        'merges the icon entry into an existing flutter.assets list',
        () async {
          final tmp = await Directory.systemTemp.createTemp('branding_merge_');
          addTearDown(() => tmp.deleteSync(recursive: true));

          final projectRoot = p.join(tmp.path, 'my_app');
          Directory(p.join(projectRoot, 'assets')).createSync(recursive: true);
          await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: my_app
environment:
  sdk: ^3.11.0
flutter:
  uses-material-design: true
  assets:
    - assets/
    - assets/icons/
''');

          final writer = BrandingWriter(zuraffaRoot: _zuraffaRoot);
          await writer.writeFlutterBranding(
            projectRoot: projectRoot,
            dryRun: false,
            verbose: false,
          );

          final pubspec = File(
            p.join(projectRoot, 'pubspec.yaml'),
          ).readAsStringSync();
          final assetKeys = RegExp(
            r'^  assets:',
            multiLine: true,
          ).allMatches(pubspec).length;
          expect(
            assetKeys,
            1,
            reason:
                'a second assets: key is a duplicate mapping key — '
                'the pubspec must stay parseable',
          );
          expect(pubspec, contains('- assets/zuraffa_app_icons/'));
          expect(
            pubspec,
            contains('- assets/icons/'),
            reason: 'original entries are preserved',
          );
        },
      );

      // ── U1 ────────────────────────────────────────────────────────────────
      test(
        'copies assets/zuraffa_app_icons/ to target project assets/ directory',
        () async {
          if (!_brandAssetsExist) {
            markTestSkipped('brand assets not checked out');
            return;
          }
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
        if (!_brandAssetsExist) {
          markTestSkipped('brand assets not checked out');
          return;
        }
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
        if (!_brandAssetsExist) {
          markTestSkipped('brand assets not checked out');
          return;
        }
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
          if (!_brandAssetsExist) {
            markTestSkipped('brand assets not checked out');
            return;
          }
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
        if (!_brandAssetsExist) {
          markTestSkipped('brand assets not checked out');
          return;
        }
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
        if (!_brandAssetsExist) {
          markTestSkipped('brand assets not checked out');
          return;
        }
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
        if (!_brandAssetsExist) {
          markTestSkipped('brand assets not checked out');
          return;
        }
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

    // ── Issue 2050 regression (supersedes the bug 735 defense) ──────────────
    // Bug 735's fix created assets/zuraffa_app_icons/ EMPTY so the injected
    // pubspec entry "is never dangling" — but git cannot track an empty
    // directory, so once the app repo commits the pubspec line the entry
    // dangles in EVERY fresh clone and the Flutter tool fails there with
    // "unable to find directory entry in pubspec.yaml" (issue 2050, fired
    // live on zik_zak: the bot commit carried the entry; the empty
    // directory it created on disk was never committed).
    //
    // New invariant: the pubspec entry is injected only when at least one
    // brand file was actually copied. These tests deliberately do NOT skip
    // when the real brand assets are absent — that blind spot (U4/U5's
    // markTestSkipped) is exactly how bug 735 shipped. A temp zuraffaRoot
    // simulates any missing/empty source deterministically on any machine.
    group(
      'issue 2050: pubspec entry is injected only when brand files were copied',
      () {
        Future<(Directory, File)> seedTargetProject() async {
          final tmp = await Directory.systemTemp.createTemp('branding_2050_');
          addTearDown(() => tmp.deleteSync(recursive: true));

          final projectRoot = p.join(tmp.path, 'my_app');
          final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
          pubspecFile.createSync(recursive: true);
          pubspecFile.writeAsStringSync('''
name: my_app
flutter:
  uses-material-design: true
''');
          return (tmp, pubspecFile);
        }

        Future<Directory> fakeZuraffaRoot({
          bool seedEmptySource = false,
        }) async {
          final fakeRoot = await Directory.systemTemp.createTemp(
            'branding_2050_root_',
          );
          addTearDown(() => fakeRoot.deleteSync(recursive: true));
          if (seedEmptySource) {
            Directory(
              p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons'),
            ).createSync(recursive: true);
          }
          return fakeRoot;
        }

        test('does not inject the pubspec entry when no brand file was copied '
            '(source absent)', () async {
          final fakeRoot = await fakeZuraffaRoot();
          expect(
            Directory(
              p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons'),
            ).existsSync(),
            isFalse,
            reason: 'precondition: brand asset source must be absent',
          );

          final (tmp, pubspecFile) = await seedTargetProject();
          final dest = Directory(
            p.join(tmp.path, 'my_app', 'assets', 'zuraffa_app_icons'),
          );

          final writer = BrandingWriter(zuraffaRoot: fakeRoot.path);
          await writer.writeFlutterBranding(
            projectRoot: p.join(tmp.path, 'my_app'),
            dryRun: false,
            verbose: false,
          );

          final content = pubspecFile.readAsStringSync();
          expect(
            content.contains('zuraffa_app_icons'),
            isFalse,
            reason:
                'git cannot commit an empty directory: an entry injected '
                'with nothing copied dangles in every fresh clone and the '
                'flutter tool fails there with "unable to find directory '
                'entry in pubspec.yaml" (issue 2050)',
          );
          expect(
            dest.existsSync(),
            isFalse,
            reason:
                'nothing was copied, so no vestigial empty directory is '
                'left behind — git would drop it from any commit anyway',
          );
        });

        test('does not inject the pubspec entry when the brand asset source '
            'exists but is empty', () async {
          final fakeRoot = await fakeZuraffaRoot(seedEmptySource: true);

          final (tmp, pubspecFile) = await seedTargetProject();
          final dest = Directory(
            p.join(tmp.path, 'my_app', 'assets', 'zuraffa_app_icons'),
          );

          final writer = BrandingWriter(zuraffaRoot: fakeRoot.path);
          await writer.writeFlutterBranding(
            projectRoot: p.join(tmp.path, 'my_app'),
            dryRun: false,
            verbose: false,
          );

          final content = pubspecFile.readAsStringSync();
          expect(
            content.contains('zuraffa_app_icons'),
            isFalse,
            reason:
                'an empty source copies nothing, so the destination stays '
                'empty and the entry would dangle in every fresh clone '
                '(issue 2050)',
          );
          expect(
            dest.existsSync(),
            isFalse,
            reason:
                'an empty source must not create the destination: a '
                'destination created empty would make every later retry '
                'skip the copy at the existing-files check, pinning the '
                'pubspec entry off until hand-deleted (issue 2050)',
          );
        });

        test('populates an existing EMPTY destination on retry and injects '
            'the pubspec entry', () async {
          final fakeRoot = await fakeZuraffaRoot();
          Directory(
            p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons'),
          ).createSync(recursive: true);
          File(
            p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons', 'logo.png'),
          ).writeAsStringSync('png');

          final (tmp, pubspecFile) = await seedTargetProject();
          final projectRoot = p.join(tmp.path, 'my_app');
          // A run whose source had nothing committable left an empty
          // destination behind; the next run must populate it, not skip.
          Directory(
            p.join(projectRoot, 'assets', 'zuraffa_app_icons'),
          ).createSync(recursive: true);

          final writer = BrandingWriter(zuraffaRoot: fakeRoot.path);
          await writer.writeFlutterBranding(
            projectRoot: projectRoot,
            dryRun: false,
            verbose: false,
          );

          expect(
            File(
              p.join(projectRoot, 'assets', 'zuraffa_app_icons', 'logo.png'),
            ).existsSync(),
            isTrue,
            reason:
                'an existing EMPTY destination must be populated on retry '
                '— skipping on a bare existsSync() check blocks branding '
                'and the pubspec entry forever',
          );
          expect(
            pubspecFile.readAsStringSync().contains(
              'assets/zuraffa_app_icons/',
            ),
            isTrue,
            reason: 'the populated destination makes the entry committable',
          );
        });

        test('does not copy .DS_Store nor inject the pubspec entry when the '
            'source holds only git-ignored metadata', () async {
          final fakeRoot = await fakeZuraffaRoot();
          final sourceDir = Directory(
            p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons'),
          );
          sourceDir.createSync(recursive: true);
          File(p.join(sourceDir.path, '.DS_Store')).writeAsStringSync('junk');

          final (tmp, pubspecFile) = await seedTargetProject();
          final dest = Directory(
            p.join(tmp.path, 'my_app', 'assets', 'zuraffa_app_icons'),
          );

          final writer = BrandingWriter(zuraffaRoot: fakeRoot.path);
          await writer.writeFlutterBranding(
            projectRoot: p.join(tmp.path, 'my_app'),
            dryRun: false,
            verbose: false,
          );

          expect(
            dest.existsSync(),
            isFalse,
            reason:
                'a destination holding only .DS_Store is invisible to git: '
                'Flutter\'s app template .gitignore drops it, so nothing '
                'was actually committed — copying it must not create the '
                'directory either (issue 2050)',
          );
          expect(
            pubspecFile.readAsStringSync().contains('zuraffa_app_icons'),
            isFalse,
            reason:
                'a .DS_Store-only destination cannot anchor the pubspec '
                'entry: git omits the directory from a fresh clone and the '
                'entry dangles there (issue 2050)',
          );
        });

        test(
          'injects the pubspec entry when at least one brand file was copied',
          () async {
            final fakeRoot = await fakeZuraffaRoot();
            Directory(
              p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons'),
            ).createSync(recursive: true);
            File(
              p.join(fakeRoot.path, 'assets', 'zuraffa_app_icons', 'logo.png'),
            ).writeAsStringSync('png');

            final (tmp, pubspecFile) = await seedTargetProject();
            final dest = Directory(
              p.join(tmp.path, 'my_app', 'assets', 'zuraffa_app_icons'),
            );

            final writer = BrandingWriter(zuraffaRoot: fakeRoot.path);
            await writer.writeFlutterBranding(
              projectRoot: p.join(tmp.path, 'my_app'),
              dryRun: false,
              verbose: false,
            );

            final content = pubspecFile.readAsStringSync();
            expect(
              content.contains('assets/zuraffa_app_icons/'),
              isTrue,
              reason:
                  'a copied brand file makes the entry committable: git '
                  'tracks the directory through its file',
            );
            expect(
              File(p.join(dest.path, 'logo.png')).existsSync(),
              isTrue,
              reason: 'the copied file backs the injected entry',
            );
          },
        );
      },
    );
  });
}
