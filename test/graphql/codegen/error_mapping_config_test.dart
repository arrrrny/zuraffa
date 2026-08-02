import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  group('ErrorMappingConfig', () {
    test('parses from .zfa.json format', () {
      final config = ErrorMappingConfig.fromJson({
        'graphql': {
          'errorMapping': {
            'global': {
              'InsufficientStockError': 'business',
              'NoActiveOrderError': 'session',
              '*Error': 'unknown',
            },
            'perOperation': {
              'addItemToOrder': {'NegativeQuantityError': 'validation'},
            },
          },
        },
      });

      expect(config.globalMappings['InsufficientStockError'], 'business');
      expect(config.globalMappings['NoActiveOrderError'], 'session');
      expect(config.globalMappings['*Error'], 'unknown');
      expect(
        config.perOperationMappings['addItemToOrder']?['NegativeQuantityError'],
        'validation',
      );
    });

    test('parses empty config', () {
      final config = ErrorMappingConfig.fromJson({});
      expect(config.globalMappings, isEmpty);
      expect(config.perOperationMappings, isEmpty);
    });

    test('global mapping lookup', () {
      final config = ErrorMappingConfig(
        globalMappings: {'InsufficientStockError': 'business'},
      );

      expect(config.getCategory('InsufficientStockError'), 'business');
      expect(config.getCategory('UnknownError'), 'unknown');
    });

    test('per-operation override takes precedence', () {
      final config = ErrorMappingConfig(
        globalMappings: {'InsufficientStockError': 'business'},
        perOperationMappings: {
          'addItemToOrder': {'InsufficientStockError': 'validation'},
        },
      );

      expect(
        config.getCategory(
          'InsufficientStockError',
          operationName: 'addItemToOrder',
        ),
        'validation',
      );
      expect(config.getCategory('InsufficientStockError'), 'business');
    });

    test('wildcard *Error pattern', () {
      final config = ErrorMappingConfig(globalMappings: {'*Error': 'unknown'});

      expect(config.getCategory('SomeRandomError'), 'unknown');
      expect(config.getCategory('NotAnError'), 'unknown');
    });

    test('unmapped non-error types default to success', () {
      final config = ErrorMappingConfig();

      expect(config.getCategory('Order'), 'success');
      expect(config.isError('Order'), false);
      // *Error-suffixed names are errors even without an explicit mapping.
      expect(config.getCategory('InsufficientStockError'), 'unknown');
      expect(config.isError('InsufficientStockError'), true);
    });

    test('isError returns true for mapped error types', () {
      final config = ErrorMappingConfig(
        globalMappings: {'InsufficientStockError': 'business'},
      );

      expect(config.isError('InsufficientStockError'), true);
      expect(config.isError('Order'), false); // Not mapped = not error
    });

    test('toFailure creates correct AppFailure types', () {
      final config = ErrorMappingConfig(
        globalMappings: {
          'InsufficientStockError': 'business',
          'NoActiveOrderError': 'session',
          'NegativeQuantityError': 'validation',
        },
      );

      final businessFailure = config.toFailure('InsufficientStockError');
      expect(businessFailure, isA<ValidationFailure>());
      expect(businessFailure.code, 'InsufficientStockError');

      final sessionFailure = config.toFailure('NoActiveOrderError');
      expect(sessionFailure, isA<UnauthorizedFailure>());
      expect(sessionFailure.code, 'NoActiveOrderError');

      final validationFailure = config.toFailure('NegativeQuantityError');
      expect(validationFailure, isA<ValidationFailure>());

      final unknownFailure = config.toFailure('UnknownError');
      expect(unknownFailure, isA<UnknownFailure>());
      expect(unknownFailure.code, 'UnknownError');
    });

    test('toFailure includes message when provided', () {
      final config = ErrorMappingConfig(globalMappings: {'XError': 'business'});
      final failure = config.toFailure('XError', message: 'Custom message');
      expect(failure.message, 'Custom message');
    });

    test('toFailure maps network category', () {
      final config = ErrorMappingConfig(
        globalMappings: {'TimeoutError': 'network'},
      );
      final failure = config.toFailure('TimeoutError');
      expect(failure, isA<NetworkFailure>());
    });
  });
}
