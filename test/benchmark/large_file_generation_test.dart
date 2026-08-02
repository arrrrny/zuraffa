import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/ast/append_executor.dart';
import 'package:zuraffa/src/core/ast/strategies/append_strategy.dart';

void main() {
  test('appends method to large class within budget', () {
    final lines = <String>[
      'class Big {',
      ...List.generate(400, (i) => '  void m$i() {}'),
      '}',
    ];
    final source = '${lines.join('\n')}\n';

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
