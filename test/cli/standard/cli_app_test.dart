// Tests for CliApp — the standardized entry point (FR-001, FR-008, FR-009).
//
// Covers U15-U22 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

import 'helpers/fake_invocation_sink.dart';

void main() {
  group('CliApp', () {
    late CliApp app;
    late StringBuffer out;
    late StringBuffer err;
    late FakeInvocationSink sink;

    setUp(() {
      sink = FakeInvocationSink();
      out = StringBuffer();
      err = StringBuffer();
      app = CliApp(
        name: 'test-app',
        version: '0.1.0',
        stdout: out,
        stderr: err,
      );
    });

    group('empty args and global flags (FR-001, FR-002)', () {
      test('U15: empty args prints help and exits 0', () async {
        final code = await app.run([]);
        expect(code, equals(0));
        expect(out.toString(), isNotEmpty);
        expect(out.toString(), contains('test-app'));
        expect(out.toString(), contains('USAGE'));
        expect(out.toString(), contains('GLOBAL OPTIONS'));
      });

      test('U16: --version prints name and version', () async {
        final code = await app.run(['--version']);
        expect(code, equals(0));
        expect(out.toString(), contains('test-app'));
        expect(out.toString(), contains('0.1.0'));
      });

      test('U17: --help prints help', () async {
        final code = await app.run(['--help']);
        expect(code, equals(0));
        expect(out.toString(), contains('USAGE'));
        expect(out.toString(), contains('CORE COMMANDS'));
      });

      test('-v is an alias for --version', () async {
        final code = await app.run(['-v']);
        expect(code, equals(0));
        expect(out.toString(), contains('test-app v0.1.0'));
      });

      test('-h is an alias for --help', () async {
        final code = await app.run(['-h']);
        expect(code, equals(0));
        expect(out.toString(), contains('USAGE'));
      });
    });

    group('unknown command (FR-001, FR-008, FR-009)', () {
      test('U18: unknown command emits notFound error shape and exits 2',
          () async {
        final code = await app.run(['unknown-command']);
        expect(code, equals(2));
        expect(err.toString(), contains('notFound'));
        expect(err.toString(), contains('unknown-command'));
      });
    });

    group('known command dispatch (FR-001)', () {
      test('U19: known command invokes handler and exits with its exit code',
          () async {
        app.register(sink.command(name: 'greet'));
        final code = await app.run(['greet']);
        expect(code, equals(0));
        expect(sink.invocations, hasLength(1));
        expect(sink.invocations.single.arguments, isEmpty);
      });

      test('known command with positional arg passes it through', () async {
        app.register(sink.command(
          name: 'greet',
          arguments: const [CommandArgument(name: 'who')],
        ));
        await app.run(['greet', 'World']);
        expect(sink.invocations.single.arguments, equals(['World']));
      });

      test('known command with --flag=value passes the value through',
          () async {
        app.register(sink.command(
          name: 'greet',
          flags: const [CommandFlag(name: '--name', takesValue: true)],
        ));
        await app.run(['greet', '--name=World']);
        expect(sink.invocations.single.flags['--name'], equals('World'));
      });

      test('handler returning ErrorResult exits with runtime code', () async {
        app.register(StandardCommand(
          name: 'boom',
          description: '',
          handler: (_) async => const ErrorResult(code: 'runtime', message: 'boom'),
        ));
        final code = await app.run(['boom']);
        expect(code, equals(1));
        expect(err.toString(), contains('boom'));
      });
    });

    group('global flags after a command (regression)', () {
      test('greet --help World does not swallow the following argument',
          () async {
        app.register(sink.command(
          name: 'greet',
          arguments: const [CommandArgument(name: 'who')],
        ));
        await app.run(['greet', '--help', 'World']);
        expect(sink.invocations, hasLength(1));
        expect(sink.invocations.single.arguments, equals(['World']));
      });

      test('greet --version World does not swallow the following argument',
          () async {
        app.register(sink.command(
          name: 'greet',
          arguments: const [CommandArgument(name: 'who')],
        ));
        await app.run(['greet', '--version', 'World']);
        expect(sink.invocations, hasLength(1));
        expect(sink.invocations.single.arguments, equals(['World']));
      });
    });

    group('JSON output (FR-008)', () {
      test('U20: --output=json emits single-line JSON to stdout', () async {
        app.register(sink.command(name: 'greet'));
        await app.run(['--output=json', 'greet']);
        final lines = out
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(lines, isNotEmpty);
        final decoded = jsonDecode(lines.last) as Map<String, Object?>;
        expect(decoded['outcome'], equals('success'));
      });

      test('error result under --output=json is valid JSON on stderr',
          () async {
        final code = await app.run(['--output=json', 'unknown']);
        expect(code, equals(2));
        final errLines = err
            .toString()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        expect(errLines, isNotEmpty);
        final decoded = jsonDecode(errLines.last) as Map<String, Object?>;
        expect(decoded['outcome'], equals('error'));
        expect(decoded['error'], isNotNull);
      });
    });

    group('handler throws (FR-008, FR-009)', () {
      test('U21: handler throw exits runtime with code 1', () async {
        app.register(StandardCommand(
          name: 'boom',
          description: '',
          handler: (_) async {
            throw StateError('boom');
          },
        ));
        final code = await app.run(['boom']);
        expect(code, equals(1));
        expect(err.toString(), contains('runtime'));
        expect(err.toString(), contains('StateError'));
      });

      test('handler throw with --verbose includes stack trace', () async {
        app.register(StandardCommand(
          name: 'boom',
          description: '',
          handler: (_) async {
            throw StateError('boom');
          },
        ));
        await app.run(['--verbose', 'boom']);
        // With --verbose, the error details should include a stackTrace.
        expect(err.toString(), contains('stackTrace'));
      });
    });

    group('usage errors (FR-008, FR-009)', () {
      test('U22: bad --output value exits usage with code 64', () async {
        final code = await app.run(['--output=xml', 'greet']);
        expect(code, equals(64));
        expect(err.toString(), contains('usage'));
        expect(err.toString(), contains('xml'));
      });

      test('--output without value exits usage', () async {
        final code = await app.run(['--output']);
        expect(code, equals(64));
      });
    });

    group('owner-app form: <ownerApp> <commandName>', () {
      test('two-token form invokes the named owner app\'s command', () async {
        final sinkA = FakeInvocationSink();
        final sinkB = FakeInvocationSink();
        app.register(sinkA.command(name: 'greet'), ownerApp: 'A');
        app.register(sinkB.command(name: 'greet'), ownerApp: 'B');
        // Ambiguous invoke-by-name should fail with conflict.
        final ambiguousCode = await app.run(['greet']);
        expect(ambiguousCode, equals(3), reason: 'conflict exit code');
        // Disambiguated via owner app.
        sinkA.invocations.clear();
        sinkB.invocations.clear();
        final code = await app.run(['A', 'greet']);
        expect(code, equals(0));
        expect(sinkA.invocations, hasLength(1));
        expect(sinkB.invocations, isEmpty);
      });
    });
  });
}
