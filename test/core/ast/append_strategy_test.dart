import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('MethodAppendStrategy appends method when missing', () {
    const source = '''
class User {
  final String name;

  User(this.name);
}
''';
    const methodSource = 'void greet() {}';
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.method(
        source: source,
        className: 'User',
        memberSource: methodSource,
      ),
    );
    expect(result.changed, isTrue);
    expect(result.source.contains('void greet() {}'), isTrue);
  });

  test('MethodAppendStrategy detects duplicate method', () {
    const source = '''
class User {
  void greet() {}
}
''';
    const methodSource = 'void greet() {}';
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.method(
        source: source,
        className: 'User',
        memberSource: methodSource,
      ),
    );
    expect(result.changed, isFalse);
  });

  test('ExportAppendStrategy adds export when missing', () {
    const source = '''
library;

class Foo {}
''';
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.export(
        source: source,
        exportPath: 'package:example/foo.dart',
      ),
    );
    expect(result.changed, isTrue);
    expect(result.source.contains("export 'package:example/foo.dart';"), isTrue);
  });
}
