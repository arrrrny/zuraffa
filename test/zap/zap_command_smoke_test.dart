// Spec 071 (issue #809) — ZAP command registration smoke test.
//
// U20 from specs/071-zuraffa-agent-protocol/tdd/test-list.md: `zfa zap`
// is registered and lists its three subcommands (the sc-pattern smoke
// test, FR-008/FR-009).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
  });

  test('U20: zfa zap --help lists the three subcommands', () async {
    final out = await runner.runCapturing(['zap', '--help']);

    for (final sub in ['conform', 'serve', 'schema']) {
      expect(
        out,
        contains(sub),
        reason: '`zfa zap --help` output must mention subcommand: $sub',
      );
    }
    // The subcommand lines exist as help entries (leading indent), not
    // just as prose.
    for (final sub in ['conform', 'serve', 'schema']) {
      final line = out
          .split('\n')
          .firstWhere(
            (l) => l.trimLeft().startsWith('$sub '),
            orElse: () => '',
          );
      expect(line, isNotEmpty, reason: 'subcommand $sub must be listed');
    }
  });

  test('U20: bare `zfa zap` prints its usage (no subcommand)', () async {
    final out = await runner.runCapturing(['zap']);
    // The runner rejects a missing subcommand with usage text (the #778
    // usage family); the real CLI maps this to exit 64 via the
    // UsageException handler in CliRunner.run.
    expect(out, contains('Missing subcommand'));
    expect(out, contains('Usage'));
    for (final sub in ['conform', 'serve', 'schema']) {
      expect(out, contains(sub));
    }
  });
}
