part of 'controller_plugin.dart';

extension ControllerPluginUtils on ControllerPlugin {
  Parameter _cancelTokenParam() {
    return Parameter(
      (p) => p
        ..name = 'cancelToken'
        ..type = refer('CancelToken?'),
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
    String domainSnake,
    bool withState,
  ) {
    final imports = <String>[
      'package:zuraffa/zuraffa.dart',
      '${config.nameSnake}_presenter.dart',
    ];

    if (withState) {
      if (config.generateState) {
        imports.add('${config.nameSnake}_state.dart');
      } else if (config.customStateName != null) {
        final stateSnake = StringUtils.camelToSnake(
          config.customStateName!.replaceAll('State', ''),
        );
        imports.add('${stateSnake}_state.dart');
      }
    }

    if (config.isCustomUseCase) {
      final types = <String>[];
      if (config.isOrchestrator) {
        for (final usecase in config.usecases) {
          final info = CommonPatterns.parseUseCaseInfo(
            usecase,
            config,
            outputDir,
          );
          if (info.returnsType != null) {
            types.add(info.returnsType!);
          }
          if (info.paramsType != null) {
            types.add(info.paramsType!);
          }
        }
      } else {
        if (config.returnsType != null) {
          types.add(config.returnsType!);
        }
        if (config.paramsType != null) {
          types.add(config.paramsType!);
        }
      }

      if (types.isNotEmpty) {
        final entityImports = CommonPatterns.entityImports(
          types,
          config,
          depth: 3,
        );
        imports.addAll(entityImports);
      }
    } else if (config.methods.any(
      (m) =>
          m == 'create' || m == 'update' || m == 'getList' || m == 'watchList',
    )) {
      final entityPath =
          '../../../domain/entities/$domainSnake/$domainSnake.dart';
      imports.add(entityPath);
    }

    return imports;
  }
}
