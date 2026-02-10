import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/ast/append_executor.dart';
import 'package:zuraffa/src/core/ast/strategies/append_strategy.dart';

void main() {
  test('append method is idempotent for random methods', () {
    final random = Random(7);
    for (var i = 0; i < 50; i += 1) {
      final methodName = 'm${random.nextInt(1000)}';
      final source = '''
class Sample {
}
''';
      final executor = AppendExecutor();
      final methodSource = 'void $methodName() {}';
      final first = executor.execute(
        AppendRequest.method(
          source: source,
          className: 'Sample',
          memberSource: methodSource,
        ),
      );
      final second = executor.execute(
        AppendRequest.method(
          source: first.source,
          className: 'Sample',
          memberSource: methodSource,
        ),
      );
      expect(first.changed, isTrue);
      expect(second.changed, isFalse);
    }
  });
}
