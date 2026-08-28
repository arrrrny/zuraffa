// SC-006 acceptance test: three different commands run through CliApp with
// --output=json each emit valid JSON on stdout matching the contract output
// schema, and exit with the contract exit code for their outcome
// (success/runtime/notFound/conflict).
//
// Pure-Dart (FR-012): no package:flutter import.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  late CliApp app;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    app = CliApp(
      name: 'machine-readable-app',
      version: '0.1.0',
      stdout: out,
      stderr: err,
    );

    // Command 1: success outcome.
    app.register(
      StandardCommand(
        name: 'succeed',
        description: 'always succeeds',
        handler: (_) async => const SuccessResult(data: {'value': 42}),
      ),
    );

    // Command 2: runtime error outcome.
    app.register(
      StandardCommand(
        name: 'fail',
        description: 'always fails with runtime',
        handler: (_) async {
          throw StateError('boom');
        },
      ),
    );

    // (Command 3 is "unknown" — not registered, so invoking it produces
    // the notFound outcome.)
  });

  test(
    'A6: success outcome emits valid JSON on stdout with exit code 0',
    () async {
      final code = await app.run(['--output=json', 'succeed']);
      expect(code, equals(0));
      final lines = out
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, isNotEmpty);
      final decoded = jsonDecode(lines.last) as Map<String, Object?>;
      expect(decoded[r'$schema'], equals('zuraffa.cli.v1'));
      expect(decoded['outcome'], equals('success'));
      expect(decoded['data'], equals({'value': 42}));
    },
  );

  test(
    'A6: runtime error outcome emits valid JSON on stderr with exit code 1',
    () async {
      final code = await app.run(['--output=json', 'fail']);
      expect(code, equals(1));
      final lines = err
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, isNotEmpty);
      final decoded = jsonDecode(lines.last) as Map<String, Object?>;
      expect(decoded[r'$schema'], equals('zuraffa.cli.v1'));
      expect(decoded['outcome'], equals('error'));
      final error = decoded['error']! as Map<String, Object?>;
      expect(error['code'], equals('runtime'));
      expect(error['message'], isA<String>());
      expect(error['details'], isA<Map>());
    },
  );

  test(
    'A6: notFound outcome emits valid JSON on stderr with exit code 2',
    () async {
      final code = await app.run(['--output=json', 'missing']);
      expect(code, equals(2));
      final lines = err
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, isNotEmpty);
      final decoded = jsonDecode(lines.last) as Map<String, Object?>;
      expect(decoded['outcome'], equals('error'));
      final error = decoded['error']! as Map<String, Object?>;
      expect(error['code'], equals('notFound'));
      expect(error['message'], contains('missing'));
      expect(error['details'], isA<Map>());
    },
  );

  test(
    'A6: conflict outcome emits valid JSON on stderr with exit code 3',
    () async {
      // Register the same command name in two owner apps to make invokes
      // ambiguous (conflict exit code).
      final out2 = StringBuffer();
      final err2 = StringBuffer();
      final app2 = CliApp(
        name: 'conflict-app',
        version: '0.1.0',
        stdout: out2,
        stderr: err2,
      );
      app2.register(
        StandardCommand(
          name: 'greet',
          description: '',
          handler: (_) async => const SuccessResult(),
        ),
        ownerApp: 'A',
      );
      app2.register(
        StandardCommand(
          name: 'greet',
          description: '',
          handler: (_) async => const SuccessResult(),
        ),
        ownerApp: 'B',
      );

      final code = await app2.run(['--output=json', 'greet']);
      expect(code, equals(3));
      final lines = err2
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, isNotEmpty);
      final decoded = jsonDecode(lines.last) as Map<String, Object?>;
      expect(decoded['outcome'], equals('error'));
      final error = decoded['error']! as Map<String, Object?>;
      expect(error['code'], equals('conflict'));
      expect(error['message'], contains('multiple apps'));
    },
  );

  test('every outcome\'s JSON has \$schema field', () async {
    // Run all three outcome types and verify $schema is always present.
    final outcomes = <String, int>{};
    await app.run(['--output=json', 'succeed']);
    await app.run(['--output=json', 'fail']);
    await app.run(['--output=json', 'missing']);
    for (final stream in [out, err]) {
      for (final line in stream.toString().split('\n')) {
        if (!line.trim().startsWith('{')) continue;
        final decoded = jsonDecode(line) as Map<String, Object?>;
        expect(
          decoded[r'$schema'],
          equals('zuraffa.cli.v1'),
          reason: 'every JSON output line must have \$schema',
        );
        outcomes[decoded['outcome'] as String] =
            (outcomes[decoded['outcome'] as String] ?? 0) + 1;
      }
    }
    expect(outcomes.keys, containsAll(['success', 'error']));
  });
}
