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
    expressions.add(refer('cancelToken'));
    return expressions;
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

  Future<List<String>> _buildImports(
    GeneratorConfig config,
    String domainSnake,
    bool withState,
  ) async {
    final imports = <String>[
      // #284/#281: Presentation layer (controller/presenter/view) must import
      // `zuraffa_flutter` (which re-exports `zuraffa` + Flutter-specific types
      // like Controller/Presenter/CleanView) instead of `zuraffa` alone —
      // generated Flutter apps depend on `zuraffa_flutter`, not `zuraffa`,
      // and `Controller` only exists in the Flutter package.
      'package:zuraffa_flutter/zuraffa_flutter.dart',
      '${config.nameSnake}_presenter.dart',
    ];

    // #284: import the entity so the generated entity types are in scope for
    // the controller's method signatures (updateProduct takes ProductPatch,
    // toggleProduct takes ProductFields, createProduct takes Product,
    // getProductList/watchProductList take ListQueryParams<Product>) and for
    // the withState `initial<Product>` field.
    //
    // #2180: the import is emitted ONLY when the generated code actually
    // references an entity type. A get/delete/watch/watchRecord-only
    // controller (no state) references none of them — the #284 unconditional
    // import was an `unused_import` warning in that generated file (it broke
    // the view compile gate's `flutter analyze`). The entity REFERENCING
    // methods are create/update/toggle (entity / Patch / Fields in the
    // signature) and getList/watchList (ListQueryParams<Entity>); get,
    // delete, watch and watchRecord reference only the id/query field types.
    if (!config.noEntity) {
      final referencesEntity =
          withState ||
          config.methods.any(
            (m) =>
                m == 'create' ||
                m == 'update' ||
                m == 'toggle' ||
                m == 'getList' ||
                m == 'watchList',
          );
      if (referencesEntity) {
        imports.add(
          '../../../domain/entities/${config.nameSnake}/${config.nameSnake}.dart',
        );
      }
      // #321: the controller's method signatures reference the id field
      // type directly (UpdateParams<IdType, Patch>,
      // ToggleParams<IdType, Field>, DeleteParams<IdType>, ...). When the
      // id field is an enum (e.g. messageTypeId: SomeEnum), the enum
      // barrel import must be emitted here — the entity file's own
      // `import '../enums/index.dart'` is private and not re-exported, so
      // the controller file references the enum symbol directly without
      // it being in scope. Primitive types are filtered out by
      // KnownTypes.isExcluded, so a plain `String` id adds nothing.
      final sigTypeImports = CommonPatterns.entityImports(
        [config.idFieldType, config.queryFieldType],
        config,
        depth: 3,
        fileSystem: fileSystem,
      );
      imports.addAll(sigTypeImports);
    }

    if (withState && !config.noEntity) {
      if (config.generateState) {
        imports.add('${config.nameSnake}_state.dart');
      } else if (config.customStateName != null) {
        final stateSnake = StringUtils.camelToSnake(
          config.customStateName!.replaceAll('State', ''),
        );
        imports.add('${stateSnake}_state.dart');
      }

      // Add entity import for initialEntity field
      final entityImports = CommonPatterns.entityImports(
        [config.name],
        config,
        depth: 3,
        fileSystem: fileSystem,
      );
      imports.addAll(entityImports);
    } else if (withState && config.noEntity) {
      // If no entity but we have state, still import state
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
          final info = await CommonPatterns.parseUseCaseInfo(
            usecase,
            config,
            outputDir,
            fileSystem: fileSystem,
          );
          if (info.paramsType != null && info.paramsType != 'NoParams') {
            types.add(info.paramsType!);
          }
        }
      } else {
        if (config.paramsType != null && config.paramsType != 'NoParams') {
          types.add(config.paramsType!);
        }
        if (config.returnsType != null && config.returnsType!.isNotEmpty) {
          types.add(config.returnsType!);
        }
      }

      if (types.isNotEmpty) {
        final entityImports = CommonPatterns.entityImports(
          types,
          config,
          depth: 3,
          fileSystem: fileSystem,
        );
        imports.addAll(entityImports);
      }
    }

    return imports;
  }
}
