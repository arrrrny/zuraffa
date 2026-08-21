import 'package:code_builder/code_builder.dart' as cb;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('UnionResultHandler', () {
    final config = ErrorMappingConfig(
      globalMappings: {
        'OrderModificationError': 'business',
        'InsufficientStockError': 'business',
        '*Error': 'unknown',
      },
    );

    final emitter = cb.DartEmitter();

    test('buildErrorConfigField bakes the mapping table', () {
      final handler = UnionResultHandler(errorConfig: config);
      final code = handler.buildErrorConfigField().accept(emitter).toString();

      expect(code.contains('_errorConfig'), true);
      expect(code.contains('ErrorMappingConfig'), true);
      expect(code.contains("'InsufficientStockError': 'business'"), true);
      expect(code.contains("'*Error': 'unknown'"), true);
      expect(code.contains("'OrderModificationError': 'business'"), true);
    });

    test('buildMapErrorMethod reads message and maps via toFailure', () {
      final handler = UnionResultHandler(errorConfig: config);
      final code = handler.buildMapErrorMethod().accept(emitter).toString();

      expect(code.contains('_mapError'), true);
      expect(code.contains('_errorConfig.toFailure'), true);
      expect(code.contains("json['message']"), true);
    });

    test('buildHandler generates __typename dispatch with operation name', () {
      final handler = UnionResultHandler(
        errorConfig: config,
        operationName: 'addItemToOrder',
      );

      final code = handler
          .buildHandler(
            unionType: cb.refer('\$\$AddItemToOrderResult'),
            fieldName: 'addItemToOrder',
            returnType: '\$\$AddItemToOrderResult',
          )
          .accept(emitter)
          .toString();

      expect(code.contains('result.data?[\'addItemToOrder\']'), true);
      expect(code.contains("data['__typename']"), true);
      expect(code.contains("operationName: 'addItemToOrder'"), true);
      expect(code.contains('_errorConfig.isError'), true);
      expect(
        code.contains("_mapError(typename, data, 'addItemToOrder')"),
        true,
      );
      expect(code.contains('\$\$AddItemToOrderResult.fromJson(data)'), true);
      expect(
        code.contains('SignalResult<\$\$AddItemToOrderResult>.failure'),
        true,
      );
      expect(
        code.contains('SignalResult<\$\$AddItemToOrderResult>.success'),
        true,
      );
      expect(code.contains("const ServerFailure('No data returned')"), true);
      expect(
        code.contains(
          "const ServerFailure('Missing __typename in union result')",
        ),
        true,
      );
    });
  });
}
