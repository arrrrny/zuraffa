import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() {
  final helper = AstHelper();

  group('Structural Equality', () {
    test(
      'areMethodsEqual returns true for identical methods with different formatting',
      () {
        const sourceA = '''
class A {
  Future<void> test(String a, {int? b}) async {}
}
''';
        const sourceB = '''
class B {
  Future < void > test ( String a , { int ? b } ) async { }
}
''';

        final unitA = helper.parseSource(sourceA).unit!;
        final unitB = helper.parseSource(sourceB).unit!;

        final methodA = helper.findMethods(helper.findClass(unitA, 'A')!).first;
        final methodB = helper.findMethods(helper.findClass(unitB, 'B')!).first;

        expect(AstHelper.areMethodsEqual(methodA, methodB), isTrue);
      },
    );

    test('areMethodsEqual returns false for different signatures', () {
      const sourceA = 'class X { void test(int a) {} }';
      const sourceB = 'class Y { void test(String a) {} }';

      final unitA = helper.parseSource(sourceA).unit!;
      final unitB = helper.parseSource(sourceB).unit!;

      final methodA = helper.findMethods(helper.findClass(unitA, 'X')!).first;
      final methodB = helper.findMethods(helper.findClass(unitB, 'Y')!).first;

      expect(AstHelper.areMethodsEqual(methodA, methodB), isFalse);
    });

    test('areConstructorsEqual handles different formatting', () {
      const sourceA = 'class A { A(this.name); }';
      const sourceB = 'class B { B ( this . name ) ; }';

      final unitA = helper.parseSource(sourceA).unit!;
      final unitB = helper.parseSource(sourceB).unit!;

      final classA = helper.findClass(unitA, 'A')!;
      final classB = helper.findClass(unitB, 'B')!;

      final constrA = classA.body.members
          .whereType<ConstructorDeclaration>()
          .first;
      final constrB = classB.body.members
          .whereType<ConstructorDeclaration>()
          .first;

      expect(AstHelper.areConstructorsEqual(constrA, constrB), isTrue);
    });
  });
}
