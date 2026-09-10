library;

// Bug #1465 — `zfa setup <name>` / `zfa app shell` must derive the app
// shell's file name and widget class from the project name instead of
// hardcoding `my_app.dart` / `MyApp`.
//
// Behavior ids trace to .specify/bugs/zfa-setup-app-name/tdd/test-list.md:
//   A1  setup dry-run previews the derived shell path (zik_zak, xyx)
//   A2  main.dart imports the derived shell and runApp()s the derived class
//   A3  a single-word name (xyx) derives XyxApp / xyx.dart the same way
//   A4  the name `my_app` collapses to the legacy literals (back-compat)
//   A5  `zfa app shell` derives the same names from the pubspec name
//   A6  a legacy my_app.dart survives regeneration untouched + named notice
//   A7  --xray keeps its wiring contract with the derived class name

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/commands/setup_command.dart';

void main() {
  group(
    'bug #1465 — name-derived app shell',
    timeout: const Timeout(Duration(minutes: 2)),
    () {
      group('A1: setup dry-run previews the derived shell path', () {
        Future<String> preview(String name) async {
          final runner = CommandRunner('zfa', 'test')
            ..addCommand(SetupCommand());
          final prints = <String>[];
          await runZoned(
            () => runner.run(['setup', name, '--dry-run', '--flutter']),
            zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, message) => prints.add(message),
            ),
          );
          return prints.join('\n');
        }

        test('zik_zak previews lib/src/app/zik_zak.dart', () async {
          final out = await preview('zik_zak');
          expect(out, contains('lib/src/app/zik_zak.dart'));
        });

        test('xyx previews lib/src/app/xyx.dart', () async {
          final out = await preview('xyx');
          expect(out, contains('lib/src/app/xyx.dart'));
        });
      });

      group('app shell end-to-end (in-process CliRunner)', () {
        late Directory tempDir;

        setUp(() async {
          tempDir = await Directory.systemTemp.createTemp('zfa_1465_');
        });

        tearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        Future<CliRunner> seedProject(String name) async {
          await File(p.join(tempDir.path, 'pubspec.yaml')).writeAsString('''
name: $name
description: Bug 1465 fixture.
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter:
    git:
      url: https://github.com/arrrrny/zuraffa
      path: zuraffa_flutter
''');
          final diDir = Directory(p.join(tempDir.path, 'lib', 'src', 'di'))
            ..createSync(recursive: true);
          await File(p.join(diDir.path, 'index.dart')).writeAsString('''
import 'package:get_it/get_it.dart';

void setupDependencies(GetIt getIt) {}
''');
          final routingDir = Directory(
            p.join(tempDir.path, 'lib', 'src', 'routing'),
          )..createSync(recursive: true);
          await File(p.join(routingDir.path, 'index.dart')).writeAsString('''
import 'package:go_router/go_router.dart';

List<GoRoute> getAllRoutes() => [];
''');
          return CliRunner(exitOnCompletion: false);
        }

        String shellSrc(String stem) => File(
          p.join(tempDir.path, 'lib', 'src', 'app', '$stem.dart'),
        ).readAsStringSync();

        String mainSrc() =>
            File(p.join(tempDir.path, 'lib', 'main.dart')).readAsStringSync();

        test('A2/A5: zik_zak derives zik_zak.dart / ZikZakApp', () async {
          final runner = await seedProject('zik_zak');
          await runner.runCapturing(['app', 'shell', '--root', tempDir.path]);

          final shell = shellSrc('zik_zak');
          expect(
            shell,
            contains('class ZikZakApp extends StatelessWidget'),
            reason: 'the shell class must derive from the package name',
          );

          final main = mainSrc();
          expect(
            main,
            contains("import 'package:zik_zak/src/app/zik_zak.dart';"),
          );
          expect(main, contains('runApp(const ZikZakApp());'));
        });

        test('A3: xyx derives xyx.dart / XyxApp the same way', () async {
          final runner = await seedProject('xyx');
          await runner.runCapturing(['app', 'shell', '--root', tempDir.path]);

          final shell = shellSrc('xyx');
          expect(shell, contains('class XyxApp extends StatelessWidget'));

          final main = mainSrc();
          expect(main, contains("import 'package:xyx/src/app/xyx.dart';"));
          expect(main, contains('runApp(const XyxApp());'));
        });

        test('A4: the name my_app collapses to the legacy literals', () async {
          final runner = await seedProject('my_app');
          await runner.runCapturing(['app', 'shell', '--root', tempDir.path]);

          final shell = shellSrc('my_app');
          expect(shell, contains('class MyApp extends StatelessWidget'));

          final main = mainSrc();
          expect(
            main,
            contains("import 'package:my_app/src/app/my_app.dart';"),
          );
          expect(main, contains('runApp(const MyApp());'));
        });

        test(
          'A6: a legacy my_app.dart survives regeneration untouched',
          () async {
            final runner = await seedProject('zik_zak');
            // A project shell-generated by an older zfa: the shell landed at
            // the old fixed path with the old fixed class.
            final legacy = File(
              p.join(tempDir.path, 'lib', 'src', 'app', 'my_app.dart'),
            );
            legacy.parent.createSync(recursive: true);
            const legacyMarker = '// legacy hand-marker — must survive';
            legacy.writeAsStringSync(
              'class MyApp extends StatelessWidget {}\n$legacyMarker\n',
            );
            final legacyBefore = legacy.readAsStringSync();

            final out = await runner.runCapturing([
              'app',
              'shell',
              '--root',
              tempDir.path,
            ]);

            expect(legacy.existsSync(), isTrue, reason: 'never deleted');
            expect(
              legacy.readAsStringSync(),
              equals(legacyBefore),
              reason: 'the legacy file is not regenerated under the new name',
            );
            expect(legacy.readAsStringSync(), contains(legacyMarker));
            expect(
              out,
              contains('my_app.dart'),
              reason: 'an informational notice names the legacy file',
            );
          },
        );

        test(
          'A7: --xray keeps its wiring contract with the derived class',
          () async {
            final runner = await seedProject('zik_zak');
            await runner.runCapturing([
              'app',
              'shell',
              '--xray',
              '--root',
              tempDir.path,
            ]);

            final main = mainSrc();
            expect(main, contains('runApp(const ZikZakApp());'));
            expect(
              main,
              contains("import 'package:zik_zak/src/app/zik_zak.dart';"),
            );
            // The #469 xray contract: web-safe stub + conditional import.
            expect(main, contains('xray_bridge_launcher_stub.dart'));
            expect(main, contains('if (dart.library.io)'));
            final shell = shellSrc('zik_zak');
            expect(
              shell,
              isNot(contains("import 'package:go_router/go_router.dart';")),
            );
          },
        );
      });
    },
  );
}
