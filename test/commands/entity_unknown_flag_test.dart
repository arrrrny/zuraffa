@Tags(['slow', 'e2e'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';

/// Regression for issue #2185.
///
/// `zfa entity create` (and the sibling manually-parsed subcommands `new`,
/// `add-field`, `enum`) parse their args with the custom `EntityCommand`
/// parser, which stores every `--flag` into a map and never validates it.
/// The handlers only read the keys they know, so an unrecognised option — a
/// typo like `--knd=value_object`, or `--totally-bogus-flag` — was silently
/// swallowed and the command exited 0 (a lying-success: the entity was
/// written as if the flag were never passed).
///
/// The contract this pins: an unknown option is a usage error (exit 2, the
/// `ExitProtocol.usage` family) that NAMES the offending flag and points at
/// `zfa entity <subcommand> --help`, and writes nothing. Driven through a
/// real subprocess ([runZfaSource]) because the entity command calls
/// `exit(N)` on its error paths (issue #506 hermetic pattern, see
/// `entity_cli_exit_code_test.dart`).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_entity_unknown_');
    // The unknown-flag guard runs inside the subcommand handler, AFTER the
    // pubspec dependency guard in `execute()`. A minimal pubspec carrying
    // both required deps gets the run past that guard so the flag check is
    // what fires.
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_entity_unknown_flag_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  String entityOutput(String name) => p.join(
    workspace.path,
    'lib',
    'src',
    'domain',
    'entities',
    name.toLowerCase(),
  );

  String enumOutput(String name) => p.join(
    workspace.path,
    'lib',
    'src',
    'domain',
    'entities',
    'enums',
    '${name.toLowerCase()}.dart',
  );

  String entityFile(String name) =>
      p.join(entityOutput(name), '${name.toLowerCase()}.dart');

  group('issue #2185 — entity create rejects unknown flags', () {
    test(
      '--totally-bogus-flag exits 2, names the flag, writes nothing',
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Bogus',
          '--totally-bogus-flag',
          '--field',
          'a:String',
        ], workingDirectory: workspace.path);

        expect(
          result.exitCode,
          equals(ExitProtocol.usage),
          reason:
              'an unknown flag must be a usage error (exit 2), not the '
              'lying-success exit 0 the bug reported.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );

        final combined = combinedOutput(result);
        expect(
          combined,
          contains('--totally-bogus-flag'),
          reason: 'the error must NAME the offending flag.',
        );
        expect(
          combined,
          contains('--help'),
          reason: 'the error must point the user at the subcommand --help.',
        );

        // The lying-success wrote the entity; the fix must write nothing.
        expect(
          Directory(entityOutput('Bogus')).existsSync(),
          isFalse,
          reason: 'a usage error must not write the entity scaffold.',
        );
      },
    );

    test('a typo of a real flag (--knd=value_object) exits 2', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Widget',
        '--knd=value_object',
        '--field',
        'a:String',
      ], workingDirectory: workspace.path);

      expect(
        result.exitCode,
        equals(ExitProtocol.usage),
        reason:
            'a misspelled --kind (--knd) must be rejected, not silently '
            'produce an entity of the wrong kind.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(combinedOutput(result), contains('--knd'));
      expect(Directory(entityOutput('Widget')).existsSync(), isFalse);
    });

    test('an unsupported short token (-nn) exits 2, not lying-success', () async {
      // `_parseArgs` only accepts two-character short options, so `-nn`
      // used to fall into `rest` (here, before -n) — a spot the guard
      // exempts — and the command succeeded as if the typo were absent.
      final result = await runZfaSource([
        'entity',
        'create',
        '-nn',
        '-n',
        'User',
        '--field',
        'a:String',
      ], workingDirectory: workspace.path);

      expect(
        result.exitCode,
        equals(ExitProtocol.usage),
        reason:
            'a dash-prefixed token that is not a valid short option must '
            'be a usage error.\nstdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(combinedOutput(result), contains('-nn'));
      expect(Directory(entityOutput('User')).existsSync(), isFalse);
    });

    test(
      'an explicit --rest option is rejected while bare positionals work',
      () async {
        // `--rest=ignored` used to be stored under the exempt `rest` key and
        // silently swallowed; a bare positional still resolves the name.
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'User',
          '--rest=ignored',
          '--field',
          'a:String',
        ], workingDirectory: workspace.path);

        expect(
          result.exitCode,
          equals(ExitProtocol.usage),
          reason:
              'an explicit --rest option must be rejected as unknown.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(combinedOutput(result), contains('--rest'));
        expect(Directory(entityOutput('User')).existsSync(), isFalse);
      },
    );

    test('a valid create still exits 0 (guard does not over-reject)', () async {
      final result = await runZfaSource([
        'entity',
        'create',
        '-n',
        'Allowed',
        '--field',
        'name:String',
      ], workingDirectory: workspace.path);

      expect(
        result.exitCode,
        equals(ExitProtocol.success),
        reason:
            'a fully valid invocation must keep working — the guard rejects '
            'only UNKNOWN flags.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(
        Directory(entityOutput('Allowed')).existsSync(),
        isTrue,
        reason: 'the valid entity must be written.',
      );
    });
  });

  group('issue #2185 — sibling subcommands reject unknown flags', () {
    test('enum --bogus exits 2 and writes nothing', () async {
      final result = await runZfaSource([
        'entity',
        'enum',
        '-n',
        'Color',
        '--value',
        'red,green',
        '--bogus',
      ], workingDirectory: workspace.path);

      expect(
        result.exitCode,
        equals(ExitProtocol.usage),
        reason:
            'entity enum must reject an unknown flag the same way create '
            'does.\nstdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(combinedOutput(result), contains('--bogus'));
      // The guard runs before any write: no enum file may be left behind.
      expect(
        File(enumOutput('Color')).existsSync(),
        isFalse,
        reason: 'a usage error must not write the enum scaffold.',
      );
    });

    test('add-field --nope exits 2', () async {
      // Seed an entity so add-field has a target; the unknown-flag guard
      // fires before any field is added regardless.
      await runZfaSource([
        'entity',
        'create',
        '-n',
        'Person',
        '--field',
        'name:String',
      ], workingDirectory: workspace.path);
      final seeded = File(entityFile('Person')).readAsStringSync();

      final result = await runZfaSource([
        'entity',
        'add-field',
        '-n',
        'Person',
        '--field',
        'age:int',
        '--nope',
      ], workingDirectory: workspace.path);

      expect(
        result.exitCode,
        equals(ExitProtocol.usage),
        reason:
            'entity add-field must reject an unknown flag.\n'
            'stdout=${result.stdout}\nstderr=${result.stderr}',
      );
      expect(combinedOutput(result), contains('--nope'));
      // Rejection must leave the seeded entity exactly as it was — the
      // guard has to run before the field is added.
      expect(
        File(entityFile('Person')).readAsStringSync(),
        equals(seeded),
        reason: 'a usage error must not modify the entity file.',
      );
    });
  });
}
