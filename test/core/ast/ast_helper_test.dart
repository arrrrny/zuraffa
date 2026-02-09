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

  test('AstHelper handles malformed source', () {
    const source = 'class Broken {';
    final result = helper.parseSource(source);
    expect(result.hasErrors, isTrue);
  });
}
