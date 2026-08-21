import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Golden: Track 3.4 — Union-to-Sealed Mapping & Error Handling', () {
    test('golden: sealed hierarchy dispatches on __typename', () {
      final schema = GraphQLSchema(
        types: {
          'Order': GraphQLObjectType(
            name: 'Order',
            fields: [
              GraphQLField(
                name: 'id',
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
              ),
              GraphQLField(
                name: 'total',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'Int'),
                ),
              ),
            ],
          ),
          'OrderModificationError': GraphQLObjectType(
            name: 'OrderModificationError',
            fields: [
              GraphQLField(
                name: 'message',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'String'),
                ),
              ),
              GraphQLField(
                name: 'errorCode',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'String'),
                ),
              ),
            ],
          ),
          'InsufficientStockError': GraphQLObjectType(
            name: 'InsufficientStockError',
            fields: [
              GraphQLField(
                name: 'message',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'String'),
                ),
              ),
              GraphQLField(
                name: 'quantityAvailable',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'Int'),
                ),
              ),
            ],
          ),
        },
      );

      final union = GraphQLUnionType(
        name: 'AddItemToOrderResult',
        possibleTypes: [
          'Order',
          'OrderModificationError',
          'InsufficientStockError',
        ],
      );

      final gen = UnionGenerator(typeMapper: TypeMapper(), schema: schema);
      final code = gen.generate(union);

      // Sealed base class
      expect(code.contains('sealed class \$\$AddItemToOrderResult'), true);

      // Entity-reuse: variants are imported, not duplicated inline.
      expect(code.contains("import '../entities/order.dart';"), true);
      expect(
        code.contains("import '../entities/order_modification_error.dart';"),
        true,
      );
      expect(
        code.contains("import '../entities/insufficient_stock_error.dart';"),
        true,
      );

      // fromJson with __typename switch
      expect(
        code.contains("final typename = json['__typename'] as String?;"),
        true,
      );
      expect(code.contains("Missing __typename in union JSON"), true);
      expect(code.contains("case 'Order':"), true);
      expect(code.contains("case 'OrderModificationError':"), true);
      expect(code.contains("case 'InsufficientStockError':"), true);
      expect(code.contains("case 'InsufficientStockError':"), true);
    });

    test('golden: datasource with union mutation maps errors to AppFailure', () {
      final gen = DatasourceGenerator(
        typeMapper: TypeMapper(),
        errorConfig: ErrorMappingConfig(
          globalMappings: {
            'InsufficientStockError': 'business',
            'OrderModificationError': 'business',
            '*Error': 'unknown',
          },
        ),
      );

      final code = gen.generate(
        name: 'Order',
        queries: [],
        mutations: [
          MutationConfig(
            fieldName: 'addItemToOrder',
            returnType: GraphQLNonNullType(
              ofType: GraphQLUnionType(
                name: 'AddItemToOrderResult',
                possibleTypes: [
                  'Order',
                  'OrderModificationError',
                  'InsufficientStockError',
                ],
              ),
            ),
            args: [
              GraphQLInputField(
                name: 'productVariantId',
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
              ),
              GraphQLInputField(
                name: 'quantity',
                type: GraphQLNonNullType(
                  ofType: GraphQLScalarType(name: 'Int'),
                ),
              ),
            ],
            document:
                '''mutation AddItemToOrder(\$productVariantId: ID!, \$quantity: Int!) {
  addItemToOrder(productVariantId: \$productVariantId, quantity: \$quantity) {
    ... on Order { id total }
    ... on OrderModificationError { message errorCode }
    ... on InsufficientStockError { message quantityAvailable }
  }
}''',
          ),
        ],
      );

      // Datasource class
      expect(code.contains('class \$OrderDatasource'), true);

      // Union handling in mutation method
      expect(code.contains('addItemToOrder'), true);
      expect(code.contains("data['__typename']"), true);
      expect(code.contains("operationName: 'addItemToOrder'"), true);
      expect(code.contains('_errorConfig.isError'), true);
      expect(code.contains('\$\$AddItemToOrderResult.fromJson(data)'), true);
      expect(
        code.contains('SignalResult<\$\$AddItemToOrderResult>.failure'),
        true,
      );
      expect(
        code.contains('SignalResult<\$\$AddItemToOrderResult>.success'),
        true,
      );

      // Error mapping helper + baked config
      expect(code.contains('_mapError'), true);
      expect(code.contains('_errorConfig'), true);
      expect(code.contains('ErrorMappingConfig'), true);
      expect(code.contains("'InsufficientStockError': 'business'"), true);
      expect(code.contains("'*Error': 'unknown'"), true);

      // Success path unwraps to the sealed union
      expect(
        code.contains(
          'return SignalResult<\$\$AddItemToOrderResult>.success(entity)',
        ),
        true,
      );
    });

    test('golden: datasource without errorConfig unwraps unions directly', () {
      final gen = DatasourceGenerator(typeMapper: TypeMapper());

      final code = gen.generate(
        name: 'Order',
        queries: [],
        mutations: [
          MutationConfig(
            fieldName: 'addItemToOrder',
            returnType: GraphQLNonNullType(
              ofType: GraphQLUnionType(
                name: 'AddItemToOrderResult',
                possibleTypes: ['Order', 'OrderModificationError'],
              ),
            ),
            args: [],
            document: '',
          ),
        ],
      );

      // No error mapping machinery
      expect(code.contains('_errorConfig'), false);
      expect(code.contains('_mapError'), false);
      expect(code.contains('\$\$AddItemToOrderResult.fromJson(data)'), true);
      expect(
        code.contains('SignalResult<\$\$AddItemToOrderResult>.success(entity)'),
        true,
      );
    });

    test('golden: wildcard *Error maps unmapped error variants', () {
      final config = ErrorMappingConfig(
        globalMappings: {
          'InsufficientStockError': 'business',
          '*Error': 'unknown',
        },
      );

      // OrderModificationError is not explicitly mapped, falls through to *Error
      expect(config.getCategory('OrderModificationError'), 'unknown');
      expect(config.getCategory('InsufficientStockError'), 'business');
      expect(config.getCategory('SomeRandomError'), 'unknown');
      expect(config.isError('Order'), false); // Success variant
    });
  });
}
