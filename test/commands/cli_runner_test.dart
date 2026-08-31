@Tags(['slow'])
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Regression tests for [CliRunner] initialization, focusing on the case where a
/// plugin-free command (`xray`) is run before a plugin-backed command in a
/// reused runner (issue #531). The two must not share a single init flag, or the
/// later command's plugin commands would never be registered.
void main() {
  group('CliRunner initialization', () {
    test(
      'registers plugin commands after a prior plugin-free xray invocation',
      () async {
        final runner = CliRunner(exitOnCompletion: false);

        // First call is the plugin-free `xray` command, which skips the plugin
        // boot. With a single init flag this would set `_initialized = true` and a
        // later plugin-backed command would be missing.
        await runner.runCapturing(['xray', '--help']);

        // A plugin-provided command (`cache`) must still be registered and
        // dispatch — otherwise the output contains "Unknown command".
        final out = await runner.runCapturing(['cache', '--help']);
        expect(out, isNot(contains('Unknown command')));
        expect(out, contains('cache'));
      },
    );

    test(
      'registers plugin commands on the first non-xray invocation',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['cache', '--help']);
        expect(out, isNot(contains('Unknown command')));
        expect(out, contains('cache'));
      },
    );
  });
}
