import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/initialize_command.dart';
import 'package:zuraffa/src/commands/setup_command.dart';
import 'package:zuraffa/src/core/dependencies/dependency_wirer.dart';

void main() {
  group('SetupCommand', () {
    test('has correct name', () {
      final cmd = SetupCommand();
      expect(cmd.name, 'setup');
    });

    test('has correct description', () {
      final cmd = SetupCommand();
      expect(cmd.description, contains('Bootstrap'));
      expect(cmd.description, contains('Flutter'));
      expect(cmd.description, contains('Dart'));
    });

    test('exposes --flutter flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('flutter'));
    });

    test('exposes --dart flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('dart'));
    });

    test('exposes --platforms option', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('platforms'));
    });

    test('exposes --dry-run flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('dry-run'));
    });

    test('exposes --force flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('force'));
    });

    test('exposes --org option', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('org'));
    });

    test('takes a positional name argument', () {
      final cmd = SetupCommand();
      // CommandRunner passes positional args via argResults.rest.
      // Verify the command doesn't declare the name as an option (it's positional).
      expect(cmd.argParser.options, isNot(contains('name')));
    });
  });

  group('InitializeCommand flags', () {
    test('accepts --deps-only flag', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--deps-only']);
      expect(result['deps-only'], isTrue);
    });

    test('accepts --no-deps flag', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--no-deps']);
      expect(result['no-deps'], isTrue);
    });

    test('--deps-only defaults to false', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse([]);
      expect(result['deps-only'], isFalse);
    });

    test('--no-deps defaults to false', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse([]);
      expect(result['no-deps'], isFalse);
    });

    test('still accepts legacy --entity option', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--entity=User']);
      expect(result['entity'], 'User');
    });

    test('still accepts --force flag', () {
      final parser = InitializeCommand.buildParser();
      final result = parser.parse(['--force']);
      expect(result['force'], isTrue);
    });
  });

  group('CLI registration', () {
    test('SetupCommand can be added to a CommandRunner', () {
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(SetupCommand());
      final setupCmd = runner.commands['setup'];
      expect(setupCmd, isNotNull);
      expect(setupCmd!.name, 'setup');
    });

    test('SetupCommand accepts both --flutter and --dart in parser', () {
      final cmd = SetupCommand();
      // Both flags can be parsed independently (the mutual-exclusion check
      // is in run(), not in the parser). Verify both are recognized.
      final result = cmd.argParser.parse(['--flutter', '--dart']);
      expect(result['flutter'], isTrue);
      expect(result['dart'], isTrue);
    });

    test('run() rejects both --flutter and --dart with UsageException', () async {
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(SetupCommand());
      await expectLater(
        runner.run(['setup', 'myapp', '--flutter', '--dart']),
        throwsA(isA<UsageException>()),
      );
    });
  });

  group('DependencyWirer', () {
    test('findMissing detects all missing deps in empty pubspec', () {
      const emptyPubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      final missing = DependencyWirer.findMissing(emptyPubspec, isFlutter: true);
      final names = missing.map((s) => s.name).toList();
      expect(names, contains('zuraffa_flutter'));
      expect(names, contains('zorphy_annotation'));
      expect(names, contains('build_runner'));
      expect(names, contains('json_annotation'));
      expect(names, contains('json_serializable'));
      expect(names, contains('mocktail'));
      expect(names, contains('flutter_lints'));
      expect(names, contains('analyzer'));
    });

    test('findMissing detects missing deps for dart project', () {
      const emptyPubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      final missing = DependencyWirer.findMissing(emptyPubspec, isFlutter: false);
      final names = missing.map((s) => s.name).toList();
      expect(names, contains('zuraffa'));
      expect(names, isNot(contains('zuraffa_flutter')));
      expect(names, isNot(contains('flutter_lints')));
    });

    test('findMissing returns empty when all deps present', () {
      const fullPubspec = '''
name: test
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa_flutter: any
  zorphy_annotation: any
  json_annotation: ^4.12.0
dev_dependencies:
  build_runner: ^2.15.2
  json_serializable: ^6.13.2
  mocktail: ^1.0.4
  flutter_lints: ^6.0.0
dependency_overrides:
  analyzer: ^13.1.0
  meta: ^1.19.0
''';
      final missing = DependencyWirer.findMissing(fullPubspec, isFlutter: true);
      expect(missing, isEmpty);
    });

    test('isFlutterProject detects flutter sdk dependency', () {
      const flutterPubspec = '''
name: test
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''';
      expect(DependencyWirer.isFlutterProject(flutterPubspec), isTrue);
    });

    test('isFlutterProject returns false for pure dart', () {
      const dartPubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      expect(DependencyWirer.isFlutterProject(dartPubspec), isFalse);
    });

    test('addOverrideToPubspec adds new section when missing', () {
      const pubspec = 'name: test\nenvironment:\n  sdk: ^3.11.0\n';
      final result = DependencyWirer.addOverrideToPubspec(pubspec, 'analyzer', '14.1.0');
      expect(result, contains('dependency_overrides:'));
      expect(result, contains('analyzer: 14.1.0'));
    });

    test('addOverrideToPubspec is idempotent', () {
      const pubspec = '''
name: test
dependency_overrides:
  analyzer: 14.1.0
''';
      final result = DependencyWirer.addOverrideToPubspec(pubspec, 'analyzer', '14.1.0');
      expect(result, equals(pubspec));
    });

    test('addOverrideToPubspec appends to existing section', () {
      const pubspec = '''
name: test
dependency_overrides:
  meta: ^1.19.0
''';
      final result = DependencyWirer.addOverrideToPubspec(pubspec, 'analyzer', '14.1.0');
      expect(result, contains('analyzer: 14.1.0'));
      expect(result, contains('meta: ^1.19.0'));
    });

    test('standardSet returns different deps for flutter vs dart', () {
      final flutterSpecs = DependencyWirer.standardSet(isFlutter: true);
      final dartSpecs = DependencyWirer.standardSet(isFlutter: false);

      final flutterNames = flutterSpecs.map((s) => s.name).toSet();
      final dartNames = dartSpecs.map((s) => s.name).toSet();

      expect(flutterNames, contains('zuraffa_flutter'));
      expect(flutterNames, isNot(contains('zuraffa')));
      expect(flutterNames, contains('flutter_lints'));

      expect(dartNames, contains('zuraffa'));
      expect(dartNames, isNot(contains('zuraffa_flutter')));
      expect(dartNames, isNot(contains('flutter_lints')));
    });
  });
}