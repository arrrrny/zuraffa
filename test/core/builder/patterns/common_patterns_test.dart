import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:code_builder/code_builder.dart';

void main() {
  test('CommonPatterns builds fields and constructors', () {
    final field = CommonPatterns.finalField('name', 'String');
    final ctor = CommonPatterns.constructor(
      parameters: [
        CommonPatterns.requiredNamedParam('name', 'String'),
      ],
    );
    final clazz = Class(
      (b) => b
        ..name = 'User'
        ..fields.add(field)
        ..constructors.add(ctor),
    );

    final output = const SpecLibrary().emitSpec(clazz);
    expect(output.contains('final String name;'), isTrue);
    expect(output.contains('User({required String name})'), isTrue);
  });
}
