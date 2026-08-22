import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  group('IntrospectCommand CLI wiring', () {
    test('graphql introspect is a recognized subcommand', () async {
      final output = await runner.runCapturing(['graphql', 'introspect']);
      // Should print usage (no URL provided) instead of erroring
      expect(output, contains('introspect'));
      expect(output, contains('endpoint-url'));
    });

    test('graphql introspect with no arguments prints usage', () async {
      final output = await runner.runCapturing(['graphql', 'introspect']);
      expect(output, contains('Usage:'));
      expect(output, contains('endpoint-url'));
    });

    test('graphql introspect with invalid URL prints error', () async {
      final output = await runner.runCapturing([
        'graphql',
        'introspect',
        'not-a-url',
      ]);
      expect(output, contains('Error: Invalid endpoint URL'));
    });

    test('graphql introspect --help prints help', () async {
      final output = await runner.runCapturing([
        'graphql',
        'introspect',
        '--help',
      ]);
      expect(output, contains('Introspect'));
      expect(output, contains('--output'));
      expect(output, contains('--dry-run'));
    });

    test('graphql command lists introspect in its help', () async {
      final output = await runner.runCapturing(['graphql', '--help']);
      expect(output, contains('introspect'));
    });

    test('zfa help mentions graphql command', () async {
      final output = await runner.runCapturing(['help']);
      // The graphql plugin should be registered
      expect(output, contains('graphql'));
    });
  });
}
