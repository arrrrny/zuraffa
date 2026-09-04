// U3: OutputFormatter has a plain mode that strips emoji + ANSI codes so
// CI logs are byte-identical across runs.

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/standard/command_model.dart';
import 'package:zuraffa/src/cli/standard/output_format.dart';

void main() {
  group('OutputFormat.plain', () {
    const fmt = OutputFormat();

    test('U3.1: error result renders without emoji', () {
      final out = fmt.plain(
        const ErrorResult(code: 'runtime', message: 'boom'),
      );
      expect(out, isNot(contains('❌')));
      expect(out, contains('[runtime]'));
      expect(out, contains('boom'));
    });

    test('U3.2: warning result renders without emoji', () {
      final out = fmt.plain(const WarningResult(message: 'careful'));
      expect(out, isNot(contains('⚠️')));
      expect(out, contains('careful'));
    });

    test('U3.3: success data renders key:value pairs without emoji', () {
      final out = fmt.plain(const SuccessResult(data: {'count': 3}));
      expect(out, contains('count: 3'));
      expect(out, isNot(contains('✅')));
    });

    test('U3.4: plain output is byte-identical across runs (no timestamps, no randomness)', () {
      final a = fmt.plain(const ErrorResult(code: 'x', message: 'm'));
      final b = fmt.plain(const ErrorResult(code: 'x', message: 'm'));
      expect(a, equals(b));
    });
  });
}
