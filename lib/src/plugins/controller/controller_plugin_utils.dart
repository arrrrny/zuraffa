part of 'controller_plugin.dart';

extension ControllerPluginUtils on ControllerPlugin {
  Parameter _cancelTokenParam() {
    return Parameter(
      (p) => p
        ..name = 'cancelToken'
        ..type = refer('CancelToken?')
        ..defaultTo = literalNull.code,
    );
  }

  List<Expression> _callArgsExpressions(String args) {
    final parts = args
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final expressions = parts.map(refer).toList();
    expressions.add(refer('token'));
    return expressions;
  }

  Code _tokenStatement() {
    return declareFinal('token')
        .assign(
          refer('cancelToken').ifNullThen(refer('createCancelToken').call([])),
        )
        .statement;
  }

  Code _updateStateStatement(Map<String, Expression> updates) {
    return refer('updateState').call([
      refer('viewState').property('copyWith').call([], updates),
    ]).statement;
  }

  Code _resultFold({
    required String resultVar,
    required List<String> successParams,
    required Block successBody,
    required List<String> failureParams,
    required Block failureBody,
  }) {
    final success = Method(
      (m) => m
        ..requiredParameters.addAll(
          successParams.map((name) => Parameter((p) => p..name = name)),
        )
        ..body = successBody,
    );
    final failure = Method(
      (m) => m
        ..requiredParameters.addAll(
          failureParams.map((name) => Parameter((p) => p..name = name)),
        )
        ..body = failureBody,
    );
    return refer(
      resultVar,
    ).property('fold').call([success.closure, failure.closure]).statement;
  }

  List<String> _buildImports(
    GeneratorConfig config,
    String entitySnake,
    bool withState,
  ) {
    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '${entitySnake}_presenter.dart',
    ];

    if (withState) {
      imports.add('${entitySnake}_state.dart');
    }

    if (config.methods.any(
      (m) =>
          m == 'create' || m == 'update' || m == 'getList' || m == 'watchList',
    )) {
      final entityPath =
          '../../../domain/entities/$entitySnake/$entitySnake.dart';
      imports.add(entityPath);
    }

    return imports;
  }
}
