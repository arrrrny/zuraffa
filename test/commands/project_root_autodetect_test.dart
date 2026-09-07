/// Bug #1267 — `zfa` resolves the project root from the raw CWD instead of
/// the closest `pubspec.yaml`. When a generation command is invoked from a
/// parent directory (or any directory that is not a project root), generated
/// files end up in the WRONG project — the filed repro had `zfa tdd run`'s
/// make step spawn `zfa entity create` against the zuraffa repo root instead
/// of the target app (`my_app/lib/src/domain/entities/auth_request/`).
///
/// The ratified remediation (assessment for #1267):
/// 1. When `-C` is not provided, search upward from the CWD for the nearest
///    `pubspec.yaml` and use that directory as the project root.
/// 2. When no ancestor carries a `pubspec.yaml`, emit the clear error
///    "No Flutter project found. Run from inside a project directory or use
///    -C <path>." instead of silently scattering files under the CWD.
/// 3. Existing `-C <project>` behavior must stay byte-identical.
///
/// Driven through a real subprocess ([runZfaSource]) — the runner applies
/// the auto-detect chdir before dispatch, and the commands `exit()` on their
/// paths (issue #506 hermetic pattern).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

import '../helpers/run_zfa_source.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory parent;
  late String myApp;

  /// The exact error text the assessment for #1267 prescribes.
  const noProjectFound =
      'No Flutter project found. Run from inside a '
      'project directory or use -C <path>.';

  setUp(() async {
    parent = await Directory.systemTemp.createTemp('zfa_1267_parent_');
    myApp = p.join(parent.path, 'my_app');
    await Directory(p.join(myApp, 'lib')).create(recursive: true);
    // Minimal pubspec for the entity command's dependency check (string
    // scan only — no `dart pub get` needed for source generation).
    await File(p.join(myApp, 'pubspec.yaml')).writeAsString('''
name: my_app
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
  });

  tearDown(() {
    if (parent.existsSync()) {
      try {
        parent.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  group('#1267 — generation commands auto-detect the project root', () {
    test(
      'entity create from a project SUBDIRECTORY writes into the project root',
      () async {
        // CWD = my_app/lib — inside the project, but not at its root.
        // Today the command reads the raw CWD, fails the dependency check
        // against my_app/lib/pubspec.yaml (missing) and refuses — even
        // though the project root with a valid pubspec is one level up.
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'AuthRequest',
          '--field',
          'method:String',
        ], workingDirectory: p.join(myApp, 'lib'));

        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          File(
            p.join(
              myApp,
              'lib',
              'src',
              'domain',
              'entities',
              'auth_request',
              'auth_request.dart',
            ),
          ).existsSync(),
          isTrue,
          reason: 'the entity lands under the TARGET project (my_app)',
        );
        // Nothing may be written outside the resolved project root.
        expect(
          Directory(p.join(myApp, 'lib', 'lib')).existsSync(),
          isFalse,
          reason: 'no CWD-relative scatter inside my_app/lib',
        );
      },
    );

    test(
      'make from a parent without any project refuses instead of scattering',
      () async {
        // The filed failure mode: invoked from a directory that is not a
        // project root, `zfa make` scattered `lib/src/...` into the CWD and
        // reported success. The parent here has no pubspec.yaml in ANY
        // ancestor, so generation must be refused with the clear error.
        final result = await runZfaSource([
          'make',
          'Item',
          '--no-entity',
          '--usecase',
          '--type=sync',
          '--domain',
          'catalog',
        ], workingDirectory: parent.path);

        expect(
          combinedOutput(result),
          contains(noProjectFound),
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.exitCode, ExitProtocol.usage);
        expect(
          Directory(p.join(parent.path, 'lib')).existsSync(),
          isFalse,
          reason: 'the usecase must NOT be scattered into the parent CWD',
        );
      },
    );

    test('build from a parent without any project refuses instead of a lying '
        'dry-run success', () async {
      // Today `zfa build --dry-run` from a rootless directory previews
      // 0 entities and exits 0 ("Dry-run completed") — a lying success
      // that never validated it was inside a project at all.
      final result = await runZfaSource([
        'build',
        '--dry-run',
      ], workingDirectory: parent.path);

      expect(
        combinedOutput(result),
        contains(noProjectFound),
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(result.exitCode, ExitProtocol.usage);
    });

    test('-C <project> keeps the exact pre-#1267 behavior', () async {
      // The guard constraint: existing -C flag behavior must not change.
      final result = await runZfaSource([
        '-C',
        myApp,
        'entity',
        'create',
        '-n',
        'Guard',
        '--field',
        'x:String',
      ], workingDirectory: parent.path);

      expect(
        result.exitCode,
        0,
        reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        File(
          p.join(
            myApp,
            'lib',
            'src',
            'domain',
            'entities',
            'guard',
            'guard.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(combinedOutput(result), isNot(contains(noProjectFound)));
    });
  });
}
