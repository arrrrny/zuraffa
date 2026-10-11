// BUG 1349 — `zfa tdd init` generates lib/app.dart importing
// zuraffa_flutter/get_it without adding the dependencies.
//
// The Flutter branch of `zfa tdd init` writes the day-zero app module
// (`lib/app.dart`, via AppModuleWriter) whose generated source imports
// `package:zuraffa_flutter/zuraffa_flutter.dart` and uses `GetIt` — but
// init only self-healed the TESTING dev_dependencies. The runtime deps
// the generated module requires (`zuraffa_flutter`, `get_it`) were never
// declared, so every test failed to compile on a fresh Flutter project:
// the day-zero baseline init promises ("Run flutter test to confirm a
// green baseline") was red out of the box.
//
// Fix contract pinned here:
//   - on a Flutter project, `zfa tdd init` ensures `zuraffa_flutter:
//     ^6.0.0` and `get_it: ^9.2.1` under `dependencies:` (RUNTIME deps —
//     the generated app module imports them in lib/, not test/);
//   - the self-heal is IDEMPOTENT (a re-run adds nothing twice) and
//     never touches already-declared entries (hand-edit preserving);
//   - a pure-Dart target is untouched by the app deps (the non-Flutter
//     init flow is unchanged: pure-Dart app modules import `zuraffa`,
//     which the project already declares);
//   - malformed pubspecs fail LOUDLY as writer failures, not crashes.
//
// PR #1461 note: the app-deps self-heal lives in
// `PubspecAppDependenciesPatcher` (extracted from InitCommand, same as
// the dev/skin patchers). The empty-inline and non-map fixture shapes
// are pinned DIRECTLY at the writer level: the tightened YAML-based
// Flutter detection (issue #1458) only routes genuine Flutter projects
// through init, and a genuine Flutter project cannot have an empty
// inline or non-map `dependencies:` value. The init-level routing
// (isFlutter → patcher runs → 'writer(s) failed' envelope) stays pinned
// by the init-driven tests below.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/writers/tdd/pubspec_app_dependencies_patcher.dart';

const String kFlutterBarrelConstraint = 'zuraffa_flutter: ^6.0.0';
const String kGetItConstraint = 'get_it: ^9.2.1';

void main() {
  group('bug 1349: zfa tdd init self-heals the Flutter app-module deps', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1349_init_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<void> seedPubspec({required bool flutter}) async {
      final buffer = StringBuffer('''
name: bug1349_init_fixture
environment:
  sdk: ^3.11.0
''');
      if (flutter) {
        buffer.writeln('''
dependencies:
  flutter:
    sdk: flutter
''');
      } else {
        buffer.writeln('dependencies:\n  path: ^1.9.0\n');
      }
      await File(
        p.join(tmpDir.path, 'pubspec.yaml'),
      ).writeAsString(buffer.toString());
    }

    Future<String> runInit() async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing(['tdd', 'init', '--project', tmpDir.path]);
    }

    String readPubspec() =>
        File(p.join(tmpDir.path, 'pubspec.yaml')).readAsStringSync();

    test(
      'Flutter project: init adds zuraffa_flutter + get_it under dependencies',
      () async {
        await seedPubspec(flutter: true);
        final out = await runInit();

        expect(CliRunner.lastDispatchedExitCode, 0, reason: out);
        final pubspec = readPubspec();
        expect(
          pubspec,
          contains(kFlutterBarrelConstraint),
          reason:
              'the generated lib/app.dart imports '
              'package:zuraffa_flutter/zuraffa_flutter.dart — init must '
              'declare it (issue #1349)',
        );
        expect(
          pubspec,
          contains(kGetItConstraint),
          reason:
              'the generated app module exposes `final GetIt di = '
              'GetIt.instance` — init must declare get_it (issue #1349)',
        );
        // Both land under `dependencies:`, never under
        // `dev_dependencies:` — lib/app.dart is runtime source.
        final depsMatch = RegExp(
          r'^dependencies:',
          multiLine: true,
        ).firstMatch(pubspec)!;
        final devMatch = RegExp(
          r'^dev_dependencies:',
          multiLine: true,
        ).firstMatch(pubspec);
        final barrelIdx = pubspec.indexOf('zuraffa_flutter');
        final getItIdx = pubspec.indexOf('get_it');
        expect(barrelIdx, greaterThan(depsMatch.start));
        expect(getItIdx, greaterThan(depsMatch.start));
        if (devMatch != null) {
          expect(barrelIdx, lessThan(devMatch.start));
          expect(getItIdx, lessThan(devMatch.start));
        }
      },
    );

    test(
      'Flutter project: the day-zero surface is self-consistent after init',
      () async {
        await seedPubspec(flutter: true);
        final out = await runInit();

        expect(exitCode, 0, reason: out);
        // The generated app module imports the barrel ...
        final appDart = File(p.join(tmpDir.path, 'lib', 'app.dart'));
        expect(appDart.existsSync(), isTrue, reason: out);
        expect(
          appDart.readAsStringSync(),
          contains('package:zuraffa_flutter/zuraffa_flutter.dart'),
        );
        // ... so the pubspec MUST declare what it imports. This is the
        // #1349 contract: day-zero green, not a compile-error baseline.
        final pubspec = readPubspec();
        expect(pubspec, contains('zuraffa_flutter:'));
        expect(pubspec, contains('get_it:'));
      },
    );

    test('self-heal is idempotent: a second run adds nothing twice', () async {
      await seedPubspec(flutter: true);
      final first = await runInit();
      expect(exitCode, 0, reason: first);
      expect(readPubspec(), contains(kFlutterBarrelConstraint));

      final second = await runInit();
      expect(exitCode, 0, reason: second);
      final pubspec = readPubspec();
      expect(
        'zuraffa_flutter'.allMatches(pubspec).length,
        1,
        reason: 'a re-run must not duplicate the barrel dependency',
      );
      expect(
        'get_it'.allMatches(pubspec).length,
        1,
        reason: 'a re-run must not duplicate get_it',
      );
    });

    test('already-declared deps are preserved byte-for-byte', () async {
      await seedPubspec(flutter: true);
      final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
      // A hand-edited pubspec that already pins both deps (with a
      // comment, as a real author would leave behind) AND carries the
      // complete testing dev_dependencies, so the dev-deps self-heal
      // has nothing to add either — isolating the byte-for-byte
      // assertion on the app-deps pass.
      await pubspecFile.writeAsString('''
name: bug1349_init_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  # pinned by hand, do not touch
  zuraffa_flutter: ^6.0.0
  get_it: ^9.2.1
dev_dependencies:
  flutter_test:
    sdk: flutter
  test: ^1.0.0
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
  coverage: ^1.15.1
  mutation_test: ^1.8.0
''');
      final before = pubspecFile.readAsStringSync();

      final out = await runInit();

      expect(exitCode, 0, reason: out);
      expect(
        pubspecFile.readAsStringSync(),
        before,
        reason: 'init must not rewrite a pubspec whose deps are complete',
      );
    });

    test(
      'pure Dart project: pubspec is untouched by the Flutter app deps',
      () async {
        await seedPubspec(flutter: false);
        final out = await runInit();

        expect(exitCode, 0, reason: out);
        expect(
          readPubspec(),
          isNot(contains('zuraffa_flutter')),
          reason:
              'a pure-Dart app module imports package:zuraffa (already '
              'declared by the project) — the Flutter self-heal must not '
              'fire on it (non-Flutter flow unchanged)',
        );
      },
    );

    test(
      'empty inline dependencies mapping is expanded without duplication',
      () async {
        // Writer-level (PR #1461): an empty inline `dependencies: {}` is
        // only reachable here, at the patcher — init's YAML-based Flutter
        // detection (issue #1458) never routes such a pubspec to the
        // app-deps self-heal.
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: bug1349_init_fixture
environment:
  sdk: ^3.11.0
dependencies: {}
''');

        await const PubspecAppDependenciesPatcher().ensure(tmpDir.path);

        final pubspec = readPubspec();
        expect(
          RegExp(r'^dependencies:', multiLine: true).allMatches(pubspec).length,
          1,
          reason:
              'the inline mapping must not cause a second top-level section',
        );
        expect(pubspec, contains(kFlutterBarrelConstraint));
        expect(pubspec, contains(kGetItConstraint));
      },
    );

    test(
      'malformed dependencies value is reported as a writer failure',
      () async {
        // Writer-level (PR #1461): the non-map refusal is pinned on the
        // patcher; the init-level 'writer(s) failed' envelope for the
        // app-deps pass is pinned by 'non-empty inline flow mapping is
        // refused loudly' below.
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: bug1349_init_fixture
environment:
  sdk: ^3.11.0
dependencies: invalid
''');

        expect(
          () => const PubspecAppDependenciesPatcher().ensure(tmpDir.path),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('non-map dependencies value'),
            ),
          ),
        );
      },
    );

    test('non-empty inline flow mapping is refused loudly', () async {
      await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: bug1349_init_fixture
environment:
  sdk: ^3.11.0
dependencies: {flutter: {sdk: flutter}}
''');

      final out = await runInit();

      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
      expect(out, contains('writer(s) failed'));
      expect(out, contains('pubspec_app_dependencies_patcher'));
      expect(out, contains('not supported by'));
    });
  });
}
