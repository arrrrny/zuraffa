part of 'local_generator.dart';

extension LocalDataSourceBuilderHelpers on LocalDataSourceBuilder {
  Method _buildMethodWithBody({
    required String name,
    required String returnType,
    required List<Parameter> parameters,
    required Code body,
    required bool isAsync,
    bool override = true,
    MethodModifier? modifier,
  }) {
    return Method(
      (m) => m
        ..name = name
        ..annotations.addAll(override ? [CodeExpression(Code('override'))] : [])
        ..returns = refer(returnType)
        ..requiredParameters.addAll(parameters)
        ..modifier = modifier ?? (isAsync ? MethodModifier.async : null)
        ..body = body,
    );
  }

  Block _returnBody(Expression expression) {
    return Block((b) => b..statements.add(expression.returned.statement));
  }

  Block _awaitBody(Expression expression) {
    return Block((b) => b..statements.add(expression.awaited.statement));
  }

  Block _awaitThenReturn(
    Expression awaitExpression,
    Expression returnExpression,
  ) {
    return Block(
      (b) => b
        ..statements.add(awaitExpression.awaited.statement)
        ..statements.add(returnExpression.returned.statement),
    );
  }

  Block _throwBody(String message) {
    return Block(
      (b) => b
        ..statements.add(
          refer(
            'UnimplementedError',
          ).call([literalString(message)]).thrown.statement,
        ),
    );
  }

  Parameter _param(String name, String type) {
    return Parameter(
      (p) => p
        ..name = name
        ..type = refer(type),
    );
  }
}
