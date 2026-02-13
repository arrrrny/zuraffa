import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:code_builder/code_builder.dart';

void main() {
  test('VpcPatterns builds controller class', () {
    final field = CommonPatterns.finalField('count', 'int');
    final method = Method(
      (b) => b
        ..name = 'increment'
        ..returns = refer('void')
        ..body = Code('count + 1;'),
    );
    final clazz = VpcPatterns.controllerClass(
      className: 'CounterController',
      baseClass: 'Controller',
      fields: [field],
      methods: [method],
    );

    final output = const SpecLibrary().emitSpec(clazz);
    expect(output.contains('class CounterController'), isTrue);
    expect(output.contains('final int count;'), isTrue);
    expect(output.contains('increment'), isTrue);
  });
}
