import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  final helper = AstHelper();

  test('AstHelper parses source and finds nodes', () {
    const source = '''
export 'a.dart';
export 'b.dart';

class User {
  final String name;

  User(this.name);

  void greet() {}
}
''';

    final result = helper.parseSource(source);
    expect(result.hasErrors, isFalse);
    expect(result.unit, isNotNull);

    final unit = result.unit!;
    final exports = helper.extractExports(unit);
    expect(exports, equals(['a.dart', 'b.dart']));

    final classNode = helper.findClass(unit, 'User');
    expect(classNode, isNotNull);

    final fields = helper.findFields(classNode!);
    expect(fields.any((f) => f.name.lexeme == 'name'), isTrue);

    final methods = helper.findMethods(classNode, name: 'greet');
    expect(methods.length, equals(1));
  });

  test('AstHelper adds method to class', () {
    const source = '''
class User {
  final String name;

  User(this.name);
}
''';
    const methodSource = 'void greet() {}';
    final updated = helper.addMethodToClass(
      source: source,
      className: 'User',
      methodSource: methodSource,
    );
    expect(updated.contains('void greet() {}'), isTrue);
  });

  test('AstHelper adds field to class', () {
    const source = '''
class User {
  User();
}
''';
    const fieldSource = 'final int age;';
    final updated = helper.addFieldToClass(
      source: source,
      className: 'User',
      fieldSource: fieldSource,
    );
    expect(updated.contains('final int age;'), isTrue);
  });

  test('AstHelper adds method to extension', () {
    const source = '''
extension UserExt on String {}
''';
    const methodSource = 'String greet() => this;';
    final updated = helper.addMethodToExtension(
      source: source,
      extensionName: 'UserExt',
      methodSource: methodSource,
    );
    expect(updated.contains('String greet() => this;'), isTrue);
  });

  test('AstHelper adds statement to function', () {
    const source = '''
void setup() {
  print('start');
}
''';
    const statementSource = "print('next');";
    final updated = helper.addStatementToFunction(
      source: source,
      functionName: 'setup',
      statementSource: statementSource,
    );
    expect(updated.contains("print('next');"), isTrue);
  });

  test('AstHelper handles malformed source', () {
    const source = 'class Broken {';
    final result = helper.parseSource(source);
    expect(result.hasErrors, isTrue);
  });
}
