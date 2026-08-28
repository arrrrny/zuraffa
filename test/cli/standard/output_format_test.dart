// Tests for OutputFormat (FR-008, FR-009).
//
// Covers U38-U40 in the test-list.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  const fmt = OutputFormat();
  final contract = CliContract.standard;

  group('OutputFormat', () {
    group('json rendering (FR-008)', () {
      test('U38: json shape for success', () {
        final result = SuccessResult(data: const {'ok': true, 'count': 3});
        final json = fmt.json(result, contract: contract);
        final decoded = jsonDecode(json) as Map<String, Object?>;
        expect(decoded[r'$schema'], equals('zuraffa.cli.v1'));
        expect(decoded['outcome'], equals('success'));
        expect(decoded['data'], equals({'ok': true, 'count': 3}));
      });

      test('json shape for error includes code/message/details', () {
        final result = ErrorResult(
          code: 'runtime',
          message: 'boom',
          details: const {'why': 'test'},
        );
        final json = fmt.json(result, contract: contract);
        final decoded = jsonDecode(json) as Map<String, Object?>;
        expect(decoded['outcome'], equals('error'));
        expect(decoded['error'], isA<Map>());
        final error = decoded['error']! as Map;
        expect(error['code'], equals('runtime'));
        expect(error['message'], equals('boom'));
        expect(error['details'], equals({'why': 'test'}));
      });

      test('json shape for warning', () {
        final result = WarningResult(message: 'deprecated', data: const {});
        final json = fmt.json(result, contract: contract);
        final decoded = jsonDecode(json) as Map<String, Object?>;
        expect(decoded['outcome'], equals('warning'));
        expect(decoded['warning'], equals('deprecated'));
      });

      test('json output is a single line (no newlines)', () {
        final result = SuccessResult(data: const {'x': 1});
        final json = fmt.json(result, contract: contract);
        expect(
          json.contains('\n'),
          isFalse,
          reason: 'JSON output must be single-line for piped parsing',
        );
      });
    });

    group('text rendering (FR-008)', () {
      test('U39: text shape for error uses emoji prefix', () {
        final result = ErrorResult(code: 'runtime', message: 'boom');
        final text = fmt.text(result);
        expect(text, startsWith('❌ '));
        expect(text, contains('boom'));
      });

      test('text shape for warning uses emoji prefix', () {
        final result = WarningResult(message: 'careful');
        final text = fmt.text(result);
        expect(text, startsWith('⚠️ '));
        expect(text, contains('careful'));
      });

      test('text shape for success uses SuccessResult.text', () {
        final result = SuccessResult(data: const {'count': 3});
        final text = fmt.text(result);
        expect(text, contains('count: 3'));
      });

      test('text shape for empty success is empty string', () {
        final result = const SuccessResult();
        expect(fmt.text(result), isEmpty);
      });
    });

    group('auto-detect (FR-009 edge case 6: non-interactive)', () {
      test('U40: detect returns json when stdout is piped (no TTY)', () {
        expect(fmt.detect(false), equals(OutputFormatKind.json));
      });

      test('detect returns text when stdout is a TTY', () {
        expect(fmt.detect(true), equals(OutputFormatKind.text));
      });
    });
  });
}
