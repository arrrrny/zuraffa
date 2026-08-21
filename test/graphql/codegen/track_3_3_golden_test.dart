import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('Golden: Track 3.3 — Subscription & Watch Methods', () {
    test('golden: datasource with watch method when subscriptions enabled', () {
      final gen = DatasourceGenerator(
        typeMapper: TypeMapper(),
        enableSubscriptions: true,
      );

      final code = gen.generate(
        name: 'Product',
        queries: [],
        mutations: [],
        watches: [
          SubscriptionConfig(
            fieldName: 'productUpdated',
            returnType: GraphQLNonNullType(
              ofType: GraphQLObjectType(name: 'Product', fields: []),
            ),
            args: [
              GraphQLInputField(
                name: 'id',
                type: GraphQLNonNullType(ofType: GraphQLScalarType(name: 'ID')),
              ),
            ],
            document: '''subscription WatchProductUpdated(\$id: ID!) {
  productUpdated(id: \$id) { id name price }
}''',
          ),
        ],
      );

      expect(code.contains('class \$ProductDatasource'), true);
      expect(code.contains('watchProductUpdated'), true);
      expect(code.contains('subscribeTo'), true);
      expect(code.contains('subscription'), true);
      expect(code.contains('SignalResult'), true);
      expect(code.contains('GraphQLClient'), true);
    });

    test('golden: datasource with watch stub when subscriptions disabled', () {
      final gen = DatasourceGenerator(
        typeMapper: TypeMapper(),
        enableSubscriptions: false,
      );

      final code = gen.generate(
        name: 'Product',
        queries: [],
        mutations: [],
        watches: [
          SubscriptionConfig(
            fieldName: 'productUpdated',
            returnType: GraphQLNonNullType(
              ofType: GraphQLObjectType(name: 'Product', fields: []),
            ),
            args: [],
            document: '',
          ),
        ],
      );

      expect(code.contains('watchProductUpdated'), true);
      expect(code.contains('subscriptions disabled'), true);
      expect(code.contains('subscribeTo'), false); // Should NOT use subscribeTo
    });

    test('golden: DI registration includes GraphQLClient', () {
      final gen = DiGenerator();
      final code = gen.generate([DiRegistration(name: 'Product')]);

      expect(code.contains('configureGraphqlDi'), true);
      expect(code.contains('GraphQLClientProvider'), true);
      expect(code.contains('GraphQLClient'), true);
      expect(code.contains('ZuraffaContainer.instance'), true);
    });

    test('golden: subscription document is valid GraphQL', () {
      final builder = DocumentBuilder(
        schema: GraphQLSchema(types: {}, queryTypeName: 'Query'),
      );

      final doc = builder.buildSubscription(
        operationName: 'WatchProductUpdated',
        fieldName: 'productUpdated',
        fields: ['id', 'name', 'price'],
        args: {'id': 'ID!'},
      );

      expect(doc.contains('subscription WatchProductUpdated'), true);
      expect(doc.contains('\$id: ID!'), true);
      expect(doc.contains('productUpdated(id: \$id)'), true);
      expect(doc.contains('id'), true);
      expect(doc.contains('name'), true);
      expect(doc.contains('price'), true);
    });
  });
}
