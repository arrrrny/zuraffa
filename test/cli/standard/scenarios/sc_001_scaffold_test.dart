// SC-001 acceptance test: an empty CliApp + one StandardCommand + run →
// handler invoked exactly once, exit code 0, stdout valid JSON when
// --output=json.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import '../helpers/fake_invocation_sink.dart';

void main() {
  test('A1: empty CliApp + one StandardCommand + run invokes handler once and exits 0', () async {
    final sink = FakeInvocationSink();
    final out = StringBuffer();
    final err = StringBuffer();

    final app = CliApp(
      name: 'scaffold-app',
      version: '0.1.0',
      stdout: out,
      stderr: err,
    );

    // Register exactly one command.
    app.register(sink.command(
      name: 'greet',
      arguments: const [CommandArgument(name: 'who', required: true)],
      flags: const [CommandFlag(name: '--loud', defaultsTo: false)],
    ));

    // Run with the command and a single positional arg.
    final code = await app.run(['greet', 'World']);

    // Assert: handler invoked exactly once.
    expect(sink.invocations, hasLength(1),
        reason: 'handler must be invoked exactly once');
    // Assert: positional arg passed through.
    expect(sink.invocations.single.arguments, equals(['World']));
    // Assert: exit code is the contract success code (0).
    expect(code, equals(0),
        reason: 'exit code must be the contract success code');

    // Now run with --output=json and assert stdout is valid JSON.
    sink.invocations.clear();
    out.clear();
    final code2 = await app.run(['--output=json', 'greet', 'World']);
    expect(code2, equals(0));
    expect(sink.invocations, hasLength(1));
    final lines = out
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final lastJsonLine = lines.lastWhere(
      (l) => l.startsWith('{'),
      orElse: () => lines.last,
    );
    final decoded = jsonDecode(lastJsonLine) as Map<String, Object?>;
    expect(decoded['outcome'], equals('success'));
    expect(decoded[r'$schema'], equals('zuraffa.cli.v1'));
  });
}
