import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/ast/append_executor.dart';
import 'package:zuraffa/src/core/ast/strategies/append_strategy.dart';

void main() {
  test('appends method to large class within budget', () {
    final buffer = StringBuffer()..writeln('class Big {');
    for (var i = 0; i < 400; i += 1) {
      buffer.writeln('  void m$i() {}');
    }
    buffer.writeln('}');
    final source = buffer.toString();

    final executor = AppendExecutor();
    final stopwatch = Stopwatch()..start();
    final result = executor.execute(
      AppendRequest.method(
        source: source,
        className: 'Big',
        memberSource: 'void extra() {}',
      ),
    );
    stopwatch.stop();

    expect(result.changed, isTrue);
    expect(result.source.contains('void extra() {}'), isTrue);
    expect(stopwatch.elapsedMilliseconds < 10000, isTrue);
  });
}
