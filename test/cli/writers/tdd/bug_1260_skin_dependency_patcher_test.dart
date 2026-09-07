// BUG 1260 — `zfa tdd init` never adds the skin lane's certified
// dependency (issue #1260, remediation 2).
//
// `zuraffa_ui` positions itself as the skin lane's certified vocabulary,
// but `zfa tdd init` only patches the TESTING dev_dependencies — the
// certified dependency is unreachable from the pipeline. A project that
// opts into skin lanes (`zfa tdd init --skin`) must get `zuraffa_ui`
// added to its `dependencies:` (it is a RUNTIME dependency: the real app
// runs under ZuraffaApp, and the widget lane's certified shell import
// resolves against it).
//
// Fix contract pinned here:
//   - `--skin` on a Flutter project adds `zuraffa_ui: ^0.1.0` under
//     `dependencies:` and is IDEMPOTENT (re-run adds nothing, breaks
//     nothing);
//   - `--skin` is an explicit opt-in: without it the pubspec is untouched
//     (the #1260 fix must not force the certified dependency on every
//     project);
//   - `--skin` on a PURE DART project is a loud misfire (zuraffa_ui is a
//     Flutter SDK package — silently corrupting the pubspec with an
//     unresolvable dependency is the dishonest outcome).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const String kCertifiedConstraint = 'zuraffa_ui: ^0.1.0';

void main() {
  group('bug 1260: zfa tdd init --skin adds the certified dependency', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug1260_init_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    Future<void> seedPubspec({required bool flutter}) async {
      final buffer = StringBuffer('''
name: bug1260_init_fixture
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

    Future<String> runInit({List<String> extra = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'init',
        '--project',
        tmpDir.path,
        ...extra,
      ]);
    }

    String readPubspec() =>
        File(p.join(tmpDir.path, 'pubspec.yaml')).readAsStringSync();

    test(
      'Flutter project: --skin adds zuraffa_ui under dependencies',
      () async {
        await seedPubspec(flutter: true);
        final out = await runInit(extra: ['--skin']);

        expect(exitCode, 0, reason: out);
        final pubspec = readPubspec();
        expect(
          pubspec,
          contains(kCertifiedConstraint),
          reason:
              'issue #1260 remediation 2: init must offer/add the skin '
              'lane certified dependency for projects that opt into skin '
              'lanes',
        );
        // The certified dependency lands under `dependencies:`, never
        // under `dev_dependencies:` — the app runs under ZuraffaApp.
        final depsIdx = pubspec.indexOf('dependencies:');
        final devIdx = pubspec.indexOf('dev_dependencies:');
        final certifiedIdx = pubspec.indexOf('zuraffa_ui');
        expect(
          certifiedIdx,
          greaterThan(depsIdx),
          reason: 'zuraffa_ui must be a runtime dependency',
        );
        if (devIdx >= 0) {
          expect(certifiedIdx, lessThan(devIdx));
        }
      },
    );

    test('--skin is idempotent: a second run adds nothing twice', () async {
      await seedPubspec(flutter: true);
      await runInit(extra: ['--skin']);
      final first = readPubspec();
      expect(first, contains(kCertifiedConstraint));

      final out = await runInit(extra: ['--skin']);
      expect(exitCode, 0, reason: out);
      final second = readPubspec();
      expect(
        'zuraffa_ui'.allMatches(second).length,
        1,
        reason: 'a re-run must not duplicate the certified dependency',
      );
    });

    test(
      'empty inline dependencies mapping is converted without duplication',
      () async {
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: bug1260_init_fixture
description: flutter fixture
environment:
  sdk: ^3.11.0
dependencies: {}
''');

        final out = await runInit(extra: ['--skin']);

        expect(exitCode, 0, reason: out);
        final pubspec = readPubspec();
        expect(
          RegExp(r'^dependencies:', multiLine: true).allMatches(pubspec).length,
          1,
          reason:
              'the inline mapping must not cause a second top-level section',
        );
        expect(pubspec, contains(kCertifiedConstraint));
      },
    );

    test(
      'malformed dependencies value is reported as a writer failure',
      () async {
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: bug1260_init_fixture
description: flutter fixture
environment:
  sdk: ^3.11.0
dependencies: invalid
''');

        final out = await runInit(extra: ['--skin']);

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('pubspec_skin_dependency_patcher'));
        expect(out, contains('non-map dependencies value'));
        expect(out, contains('writer(s) failed'));
        expect(out, isNot(contains('_TypeError')));
      },
    );

    test(
      'non-empty inline dependencies mapping remains a writer failure',
      () async {
        await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString('''
name: bug1260_init_fixture
description: flutter fixture
environment:
  sdk: ^3.11.0
dependencies: {flutter: any}
''');

        final out = await runInit(extra: ['--skin']);

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('Inline `dependencies: {...}` mappings'));
        final pubspec = readPubspec();
        expect(pubspec, contains('dependencies: {flutter: any}'));
        expect(
          RegExp(r'^dependencies:', multiLine: true).allMatches(pubspec).length,
          1,
        );
      },
    );

    test('WITHOUT --skin the pubspec is untouched by the certified dependency '
        '(explicit opt-in)', () async {
      await seedPubspec(flutter: true);
      final out = await runInit();

      expect(exitCode, 0, reason: out);
      expect(
        readPubspec(),
        isNot(contains('zuraffa_ui')),
        reason:
            'the certified vocabulary is opt-in (skin lanes); init must '
            'not force it on every project',
      );
    });

    test(
      'pure Dart project: --skin is a loud misfire, not a corrupt pubspec',
      () async {
        await seedPubspec(flutter: false);
        final out = await runInit(extra: ['--skin']);

        expect(
          exitCode,
          isNot(0),
          reason:
              'zuraffa_ui is a Flutter SDK package; a pure-Dart target '
              'cannot resolve it — the misfire must be loud (got:\n$out)',
        );
        expect(
          out,
          contains('zuraffa_ui'),
          reason: 'the misfire names the certified dependency',
        );
      },
    );
  });
}
