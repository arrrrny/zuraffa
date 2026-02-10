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
    expect(
      result.source.contains("export 'package:example/foo.dart';"),
      isTrue,
    );
  });

  test('ImportAppendStrategy adds import when missing', () {
    const source = '''
library;

class Foo {}
''';
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.import(
        source: source,
        importPath: 'package:example/bar.dart',
      ),
    );
    expect(result.changed, isTrue);
    expect(
      result.source.contains("import 'package:example/bar.dart';"),
      isTrue,
    );
  });

  test('FieldAppendStrategy appends field when missing', () {
    const source = '''
class User {
  User();
}
''';
    const fieldSource = 'final int age;';
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.field(
        source: source,
        className: 'User',
        memberSource: fieldSource,
      ),
    );
    expect(result.changed, isTrue);
    expect(result.source.contains('final int age;'), isTrue);
  });

  test('ExtensionMethodAppendStrategy appends method', () {
    const source = '''
extension UserExt on String {}
''';
    const methodSource = 'String greet() => this;';
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.extensionMethod(
        source: source,
        className: 'UserExt',
        memberSource: methodSource,
      ),
    );
    expect(result.changed, isTrue);
    expect(result.source.contains('String greet() => this;'), isTrue);
  });

  test('FunctionStatementAppendStrategy appends statement', () {
    const source = '''
void setup() {
  print('start');
}
''';
    const statementSource = "print('next');";
    final executor = AppendExecutor();
    final result = executor.execute(
      const AppendRequest.functionStatement(
        source: source,
        functionName: 'setup',
        memberSource: statementSource,
      ),
    );
    expect(result.changed, isTrue);
    expect(result.source.contains("print('next');"), isTrue);
  });

  test('AppendExecutor returns no strategy found for unknown', () {
    const source = 'class Foo {}';
    final executor = AppendExecutor(strategies: const []);
    final result = executor.execute(
      const AppendRequest.import(
        source: source,
        importPath: 'package:example/bar.dart',
      ),
    );
    expect(result.changed, isFalse);
    expect(result.message, equals('No strategy found'));
  });
}
