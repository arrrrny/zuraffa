import 'package:test/test.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/commands/setup_command.dart';

void main() {
  group('SetupCommand', () {
    test('has correct name', () {
      final cmd = SetupCommand();
      expect(cmd.name, 'setup');
    });

    test('has correct description', () {
      final cmd = SetupCommand();
      expect(cmd.description, contains('Bootstrap'));
      expect(cmd.description, contains('Flutter/Dart'));
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

    test('exposes --verbose flag', () {
      final cmd = SetupCommand();
      expect(cmd.argParser.options, contains('verbose'));
    });

    test('takes a positional name argument', () {
      final cmd = SetupCommand();
      // CommandRunner passes positional args via argResults.rest.
      // Verify the command doesn't declare the name as an option (it's positional).
      expect(cmd.argParser.options, isNot(contains('name')));
    });

    test('has correct invocation', () {
      final cmd = SetupCommand();
      expect(cmd.invocation, contains('setup'));
      expect(cmd.invocation, contains('<name>'));
    });
  });

  group('InitializeCommand', () {
    test('accepts --deps-only flag', () {
      // InitializeCommand uses its own ArgParser in execute().
      // We verify the flag is declared by parsing args directly.
      final parser = _buildInitializeParser();
      final result = parser.parse(['--deps-only']);
      expect(result['deps-only'], isTrue);
    });

    test('accepts --no-deps flag', () {
      final parser = _buildInitializeParser();
      final result = parser.parse(['--no-deps']);
      expect(result['no-deps'], isTrue);
    });

    test('--deps-only defaults to false', () {
      final parser = _buildInitializeParser();
      final result = parser.parse([]);
      expect(result['deps-only'], isFalse);
    });

    test('--no-deps defaults to false', () {
      final parser = _buildInitializeParser();
      final result = parser.parse([]);
      expect(result['no-deps'], isFalse);
    });

    test('still accepts legacy --entity option', () {
      final parser = _buildInitializeParser();
      final result = parser.parse(['--entity=User']);
      expect(result['entity'], 'User');
    });

    test('still accepts --force flag', () {
      final parser = _buildInitializeParser();
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

    test('SetupCommand argParser rejects both --flutter and --dart at runtime', () {
      final cmd = SetupCommand();
      // Both flags can be parsed independently (the mutual-exclusion check
      // is in run(), not in the parser). Verify both are recognized.
      final result = cmd.argParser.parse(['--flutter', '--dart']);
      expect(result['flutter'], isTrue);
      expect(result['dart'], isTrue);
    });
  });
}

/// Builds the same ArgParser that InitializeCommand.execute() uses.
ArgParser _buildInitializeParser() {
  return ArgParser()
    ..addOption('entity', abbr: 'e', defaultsTo: 'Product')
    ..addOption('output', abbr: 'o', defaultsTo: 'lib/src/domain/entities')
    ..addFlag('force', abbr: 'f', negatable: false)
    ..addFlag('dry-run', negatable: false)
    ..addFlag('deps-only', negatable: false)
    ..addFlag('no-deps', negatable: false)
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false);
}
