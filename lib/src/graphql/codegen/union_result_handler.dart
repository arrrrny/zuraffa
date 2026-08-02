import 'package:code_builder/code_builder.dart' as cb;

import 'error_mapping_config.dart';

/// Generates the union-result handling code emitted into generated
/// datasources, mapping error variants to [AppFailure] and success variants
/// to the sealed union object.
///
/// Unions are dispatched at runtime on their `__typename` discriminator
/// through the datasource's `_errorConfig` / `_mapError` members:
///
/// ```dart
/// final data = result.data?['addItemToOrder'] as Map<String, dynamic>?;
/// if (data == null) {
///   return SignalResult<$$AddItemToOrderResult>.failure(
///     const ServerFailure('No data returned'),
///   );
/// }
/// final typename = data['__typename'] as String?;
/// if (typename == null) {
///   return SignalResult<$$AddItemToOrderResult>.failure(
///     const ServerFailure('Missing __typename in union result'),
///   );
/// }
/// if (_errorConfig.isError(typename, operationName: 'addItemToOrder')) {
///   return SignalResult<$$AddItemToOrderResult>.failure(
///     _mapError(typename, data, 'addItemToOrder'),
///   );
/// }
/// final entity = $$AddItemToOrderResult.fromJson(data);
/// return SignalResult<$$AddItemToOrderResult>.success(entity);
/// ```
///
/// Used by [DatasourceGenerator] to handle union-returning operations.
class UnionResultHandler {
  UnionResultHandler({required this.errorConfig, this.operationName});

  /// The error mapping table baked into the generated datasource.
  final ErrorMappingConfig errorConfig;

  /// GraphQL operation (field) name, used for per-operation mappings.
  final String? operationName;

  /// Generate the `_errorConfig` field declaration for a datasource.
  ///
  /// The field is initialized from [errorConfig] so global and per-operation
  /// mappings from `.zfa.json` take effect at runtime.
  cb.Field buildErrorConfigField() {
    return cb.Field((f) {
      f
        ..name = '_errorConfig'
        ..modifier = cb.FieldModifier.final$
        ..type = cb.refer('ErrorMappingConfig')
        ..assignment = cb.Code(_configSource());
    });
  }

  /// Generate the `_mapError` helper method for a datasource.
  ///
  /// Reads the optional `message` from the variant JSON and converts the
  /// error type name to an [AppFailure] via [ErrorMappingConfig.toFailure].
  cb.Method buildMapErrorMethod() {
    return cb.Method((m) {
      m
        ..name = '_mapError'
        ..returns = cb.refer('AppFailure')
        ..requiredParameters.addAll([
          cb.Parameter(
            (p) => p
              ..name = 'errorType'
              ..type = cb.refer('String'),
          ),
          cb.Parameter(
            (p) => p
              ..name = 'json'
              ..type = cb.refer('Map<String, dynamic>'),
          ),
          cb.Parameter(
            (p) => p
              ..name = 'operationName'
              ..type = cb.refer('String'),
          ),
        ])
        ..body = cb.Block((bl) {
          bl.statements.add(
            cb.Code("final message = json['message'] as String? ?? errorType;"),
          );
          bl.statements.add(
            cb.Code(
              'return _errorConfig.toFailure(errorType, message: message, operationName: operationName);',
            ),
          );
        });
    });
  }

  /// Generate the statements that handle a union-returning operation.
  ///
  /// The emitted block checks `__typename` against [_errorConfig]; error
  /// variants return [SignalResult.failure] with the mapped [AppFailure],
  /// success variants unwrap to the sealed `$$Union` object.
  ///
  /// - [unionType]: the GraphQL union return type.
  /// - [fieldName]: the GraphQL field the result came from.
  /// - [returnType]: the Dart generic of the generated `SignalResult` (e.g.
  ///   `$$AddItemToOrderResult`).
  /// - [resultVar]: the name of the local `QueryResult`/`MutationResult`
  ///   variable (defaults to `result`).
  cb.Code buildHandler({
    required cb.Reference unionType,
    required String fieldName,
    required String returnType,
    String resultVar = 'result',
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
      "final data = $resultVar.data?['$fieldName'] as Map<String, dynamic>?;",
    );
    buffer.writeln('if (data == null) {');
    buffer.writeln('  return SignalResult<$returnType>.failure(');
    buffer.writeln("    const ServerFailure('No data returned'),");
    buffer.writeln('  );');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln("final typename = data['__typename'] as String?;");
    buffer.writeln('if (typename == null) {');
    buffer.writeln('  return SignalResult<$returnType>.failure(');
    buffer.writeln("    const ServerFailure('Missing __typename in union result'),");
    buffer.writeln('  );');
    buffer.writeln('}');
    buffer.writeln('');
    final opArg = operationName == null
        ? ''
        : ", operationName: '$operationName'";
    final opArgForMapError = operationName == null
        ? "''"
        : "'$operationName'";
    buffer.writeln('if (_errorConfig.isError(typename$opArg)) {');
    buffer.writeln(
      '  return SignalResult<$returnType>.failure(_mapError(typename, data, $opArgForMapError));',
    );
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('final entity = ${unionType.symbol}.fromJson(data);');
    buffer.writeln('return SignalResult<$returnType>.success(entity);');

    return cb.Code(buffer.toString());
  }

  /// Render [errorConfig] as a Dart `ErrorMappingConfig(...)` literal.
  String _configSource() {
    final global = errorConfig.globalMappings.entries
        .map((e) => "'${e.key}': '${e.value}'")
        .join(', ');
    final perOp = errorConfig.perOperationMappings.entries
        .map(
          (e) =>
              "'${e.key}': {${e.value.entries.map((ee) => "'${ee.key}': '${ee.value}'").join(', ')}}",
        )
        .join(', ');
    return 'ErrorMappingConfig(globalMappings: {$global}, perOperationMappings: {$perOp})';
  }
}
