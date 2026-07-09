import 'package:meta/meta.dart';

/// Immutable metadata for a single registered UseCase VM Service extension.
@immutable
class ApiEndpoint {
  /// Full method name: e.g. `ext.zuraffa.product.getProduct`
  final String method;

  /// Domain segment: e.g. `product`
  final String domain;

  /// UseCase name camelCase: e.g. `getProduct`
  final String usecase;

  /// Parameter name → Dart type map: e.g. `{'id': 'String'}`
  final Map<String, String> params;

  /// Return type name: e.g. `Product` or `List<Product>`
  final String returns;

  /// True when the UseCase extends StreamUseCase.
  final bool isStream;

  const ApiEndpoint({
    required this.method,
    required this.domain,
    required this.usecase,
    required this.params,
    required this.returns,
    required this.isStream,
  });

  Map<String, dynamic> toJson() => {
    'method': method,
    'domain': domain,
    'usecase': usecase,
    'params': params,
    'returns': returns,
    'isStream': isStream,
  };
}
