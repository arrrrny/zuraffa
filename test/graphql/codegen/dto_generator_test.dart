import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('DtoGenerator', () {
    final mapper = TypeMapper();
    final gen = DtoGenerator(typeMapper: mapper);

    test('generates DTO with input fields', () {
      final type = GraphQLInputObjectType(
        name: 'ProductListOptions',
        inputFields: [
          GraphQLInputField(
            name: 'take',
            type: GraphQLScalarType(name: 'Int'),
          ),
          GraphQLInputField(
            name: 'skip',
            type: GraphQLScalarType(name: 'Int'),
          ),
          GraphQLInputField(
            name: 'sort',
            type: GraphQLScalarType(name: 'String'),
          ),
        ],
      );

      final code = gen.generate(type);
      expect(code.contains('class \$ProductListOptions'), true);
      expect(code.contains('final int? take'), true);
      expect(code.contains('final int? skip'), true);
      expect(code.contains('final String? sort'), true);
      expect(code.contains('toJson'), true);
      expect(code.contains('copyWith'), true);
    });
  });
}
