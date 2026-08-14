import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import '../../commands/view_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/plugin_context.dart';
import '../../core/context/file_system.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/adaptive_layout_scaffold_builder.dart';
import 'builders/view_class_builder.dart';
import 'capabilities/create_view_capability.dart';
import 'capabilities/custom_view_capability.dart';
import 'capabilities/register_view_capability.dart';
import '../../state/generator/state_generator.dart';
import '../../state/generator/view_template_generator.dart';

import 'package:code_builder/code_builder.dart';

/// Generates Flutter view classes for presentation pages.
class ViewPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final ViewClassBuilder classBuilder;
  final FileSystem fileSystem;

  ViewPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const ViewClassBuilder(),
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create();

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateViewCapability(this),
    CustomViewCapability(this),
    RegisterViewCapability(this),
  ];

  @override
  String get id => 'view';

  @override
  String get name => 'View Plugin';

  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => ViewCommand(this);

  @override
  JsonSchema get configSchema => {
    'type': 'object',
    'properties': {
      'vpc': {
        'type': 'boolean',
        'default': false,
        'description': 'Generate full View/Presenter/Controller set',
      },
      'adaptive-layouts': {
        'type': 'boolean',
        'default': false,
        'description': 'Scaffold platform/device-specific layout files',
      },
      'platform-shells': {
        'type': 'boolean',
        'default': false,
        'description': 'Enable shell-oriented adaptive layout scaffolding',
      },
      'layout-targets': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Adaptive layout targets, e.g. mobile,tablet,desktop,macos',
      },
      'v6-state': {
        'type': 'boolean',
        'default': false,
        'description':
            'Generate v6 dual-layer state (DomainState + ViewState + '
            'DualLayerPresenter) and ControlledWidget/FragmentBuilder-based '
            'views instead of the legacy v5 monolithic state',
      },
    },
  };

  @override
  Future<List<GeneratedFile>> generateWithContext(PluginContext context) async {
    final config = GeneratorConfig(
      name: context.core.name,
      outputDir: context.core.outputDir,
      dryRun: context.core.dryRun,
      force: context.core.force,
      verbose: context.core.verbose,
      revert: context.core.revert,
      generateView: true,
      generateVpcs: context.get<bool>('vpc') ?? context.data['vpcs'] == true,
      generateController: context.data['controller'] == true,
      generatePresenter: context.data['presenter'] == true,
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      usecases: (context.data['usecases'] as List?)?.cast<String>() ?? [],
      domain: context.data['domain'],
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      noEntity: context.data['no-entity'] == true,
      generateState: context.data['state'] == true,
      generateDi: context.data['di'] == true,
      generateXRay: context.data['xray'] == true,
      generateV6State: context.data['v6-state'] == true,
    );

    return generate(config, context: context);
  }

  /// Generates v6 dual-layer state files + ControlledWidget-based view.
  ///
  /// Emits:
  /// - `{Name}DomainState` (regenerated every build, signal slices)
  /// - `{Name}ViewState` (scaffolded once, preserved)
  /// - `{Name}Presenter` (extends DualLayerPresenter, scaffolded once)
  /// - `{Name}View` (extends ControlledWidget, uses FragmentBuilder)
  Future<List<GeneratedFile>> _generateV6State(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    final fs = context?.fileSystem ?? fileSystem;
    final entityName = config.name;
    final domainSnake = config.effectiveDomain;
    final stateDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
    );

    // Derive use-case bindings from requested methods. Each method (get,
    // update, etc.) becomes one signal slice in the DomainState.
    final methods = config.methods.isNotEmpty
        ? config.methods
        : ['get', 'update'];
    final useCaseBindings = <UseCaseBinding>[];
    final sliceKeys = <String>[];
    for (final method in methods) {
      final sliceKey = _sliceKeyForMethod(method);
      final returnType = _returnTypeForMethod(method, entityName);
      final useCaseFieldName = '_${sliceKey}UseCase';
      final paramsConstructor = '${_pascalCase(method)}${entityName}Params';
      useCaseBindings.add(
        UseCaseBinding(
          sliceKey: sliceKey,
          useCaseFieldName: useCaseFieldName,
          paramsConstructor: paramsConstructor,
          returnType: returnType,
          cacheable: config.enableCache,
        ),
      );
      sliceKeys.add(sliceKey);
    }

    final cacheableSliceKeys = config.enableCache
        ? <String>{...sliceKeys}
        : null;

    final generatedFiles = <GeneratedFile>[];

    // 1. DomainState (always regenerated)
    final stateGen = StateGenerator(outputDir: stateDirPath);
    final domainPath = stateGen.generateDomainState(
      entityName,
      useCases: useCaseBindings,
      cacheableSliceKeys: cacheableSliceKeys,
    );
    generatedFiles.add(
      GeneratedFile(
        path: domainPath,
        type: 'domain_state',
        action: 'overwritten',
        content: fs.readSync(domainPath),
      ),
    );

    // 2. ViewState (scaffolded once, preserved)
    final viewStatePath = stateGen.generateViewState(entityName);
    final viewStateAction = stateGen.preservedFiles.contains(viewStatePath)
        ? 'skipped'
        : 'created';
    generatedFiles.add(
      GeneratedFile(
        path: viewStatePath,
        type: 'view_state',
        action: viewStateAction,
        content: fs.readSync(viewStatePath),
      ),
    );

    // 3. Presenter (scaffolded once, preserved)
    final viewGen = ViewTemplateGenerator(outputDir: stateDirPath);
    final presenterPath = viewGen.generatePresenter(
      entityName,
      useCases: sliceKeys,
    );
    generatedFiles.add(
      GeneratedFile(
        path: presenterPath,
        type: 'presenter',
        action: 'created',
        content: fs.readSync(presenterPath),
      ),
    );

    // 4. View (ControlledWidget + FragmentBuilder + SignalBuilder)
    final viewPath = viewGen.generateView(entityName, useCases: sliceKeys);
    generatedFiles.add(
      GeneratedFile(
        path: viewPath,
        type: 'view',
        action: config.force ? 'overwritten' : 'created',
        content: fs.readSync(viewPath),
      ),
    );

    return generatedFiles;
  }

  /// Maps a CRUD method name to a semantic signal-slice key.
  String _sliceKeyForMethod(String method) {
    return switch (method) {
      'get' || 'watch' => 'entity',
      'getList' || 'watchList' || 'list' => 'entities',
      'create' => 'created',
      'update' => 'updated',
      'delete' => 'deleted',
      'toggle' => 'toggled',
      _ => method,
    };
  }

  /// Derives the slice return type for a method.
  String _returnTypeForMethod(String method, String entityName) {
    return switch (method) {
      'getList' || 'watchList' || 'list' => 'List<$entityName>',
      _ => entityName,
    };
  }

  /// Converts a lowercase word to PascalCase.
  String _pascalCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateView && !config.generateVpcs && !config.revert) {
      return [];
    }

    // v6 dual-layer state path: generate DomainState + ViewState +
    // DualLayerPresenter + ControlledWidget/FragmentBuilder-based view.
    if (config.generateV6State) {
      return _generateV6State(config, context: context);
    }

    if (config.outputDir != outputDir ||
        config.dryRun != options.dryRun ||
        config.force != options.force ||
        config.verbose != options.verbose ||
        config.revert != options.revert) {
      final delegator = ViewPlugin(
        outputDir: config.outputDir,
        options: GeneratorOptions(
          dryRun: config.dryRun,
          force: config.force,
          verbose: config.verbose,
          revert: config.revert,
        ),
        classBuilder: classBuilder,
        fileSystem: context?.fileSystem,
      );
      return delegator.generate(config, context: context);
    }

    final fs = context?.fileSystem ?? fileSystem;

    final generatedFiles = <GeneratedFile>[];
    final entityName = config.name;
    final domainSnake = config.effectiveDomain;
    final viewDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
    );

    final hasList =
        config.methods.contains('getList') ||
        config.methods.contains('watchList');
    final hasDetail =
        config.methods.contains('get') || config.methods.contains('watch');
    final isMasterDetail = hasList && hasDetail;

    if (hasList || !hasDetail || !isMasterDetail) {
      final viewName = '${entityName}View';
      final fileName = '${config.nameSnake}_view.dart';
      final filePath = path.join(viewDirPath, fileName);

      final files = await _generateViewFile(
        config: config,
        viewName: viewName,
        filePath: filePath,
        domainSnake: domainSnake,
        initialMethod: hasList
            ? (config.methods.contains('watchList') ? 'watchList' : 'getList')
            : (hasDetail
                  ? (config.methods.contains('watch') ? 'watch' : 'get')
                  : null),
        fileSystem: fs,
        context: context,
      );
      generatedFiles.addAll(files);
    }

    if (isMasterDetail) {
      final viewName = '${entityName}DetailView';
      final fileName = '${config.nameSnake}_detail_view.dart';
      final filePath = path.join(viewDirPath, fileName);

      final files = await _generateViewFile(
        config: config,
        viewName: viewName,
        filePath: filePath,
        domainSnake: domainSnake,
        initialMethod: config.methods.contains('watch') ? 'watch' : 'get',
        fileSystem: fs,
        context: context,
      );
      generatedFiles.addAll(files);
    }

    return generatedFiles;
  }

  Future<List<GeneratedFile>> _generateViewFile({
    required GeneratorConfig config,
    required String viewName,
    required String filePath,
    required String domainSnake,
    String? initialMethod,
    required FileSystem fileSystem,
    PluginContext? context,
  }) async {
    final entityName = config.name;
    final controllerName = config.effectiveControllerName;
    final presenterName = config.effectivePresenterName;

    final useDi = config.generateDi && !config.usesCustomVpc;
    final repoFields = useDi ? <Field>[] : _buildRepoFields(config);

    final routeFields = _buildRouteFieldsForView(
      config,
      viewName.endsWith('DetailView'),
    );

    final repoPresenterArgs = useDi
        ? <String>[]
        : _buildRepoPresenterArgs(config);
    final imports = _buildImports(config, domainSnake, useDi);
    final effectiveEntityName = config.usesCustomVpc
        ? config.effectivePresenterName.replaceAll('Presenter', '')
        : entityName;

    final initialMethodCall = initialMethod != null
        ? _buildNamedInitialMethodCall(
            config,
            effectiveEntityName,
            initialMethod,
          )
        : Block((b) => b);

    final isCustom =
        !config.generateVpcs &&
        !config.generateController &&
        !config.generatePresenter &&
        !config.isEntityBased &&
        !config.isOrchestrator;

    final withState = config.generateState || config.customStateName != null;
    final content = classBuilder.build(
      ViewClassSpec(
        viewName: viewName,
        controllerName: controllerName,
        presenterName: presenterName,
        entityName: config.noEntity ? null : entityName,
        entityCamel: config.noEntity ? null : config.nameCamel,
        repoFields: repoFields,
        routeFields: routeFields,
        repoPresenterArgs: repoPresenterArgs,
        initialMethodCall: initialMethodCall,
        imports: imports,
        withState: withState,
        isCustom: isCustom,
        isStateful: isCustom && config.generateState,
        stateClassName: config.effectiveStateName,
        withXRay: config.generateXRay,
      ),
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    final generatedFiles = <GeneratedFile>[
      await FileUtils.writeFile(
        filePath,
        content,
        'view',
        force: options.force,
        dryRun: options.dryRun,
        verbose: options.verbose,
        revert: config.revert,
        skipRevertIfExisted: true,
        fileSystem: fileSystem,
      ),
    ];

    generatedFiles.addAll(
      await AdaptiveLayoutScaffoldBuilder(
        outputDir: outputDir,
        options: options,
        fileSystem: fileSystem,
      ).generate(
        config,
        viewName: viewName,
        domainSnake: domainSnake,
        controllerName: controllerName,
        presenterName: presenterName,
        withState: withState,
        context: context,
      ),
    );

    return generatedFiles;
  }

  Future<List<GeneratedFile>> generateWithCustomParameters(
    GeneratorConfig config, {
    required String viewName,
    required String filePath,
    required List<Parameter> customParameters,
    required List<String> additionalImports,
    Map<String, dynamic> args = const {},
    FileSystem? contextFs,
  }) async {
    final fs = contextFs ?? fileSystem;
    final domainSnake = config.effectiveDomain;
    final entityName = config.name;
    final controllerName = config.effectiveControllerName;
    final presenterName = config.effectivePresenterName;

    final useDi = config.generateDi && !config.usesCustomVpc;
    final repoFields = useDi ? <Field>[] : _buildRepoFields(config);
    final routeFields = _buildRouteFieldsForView(
      config,
      viewName.endsWith('DetailView'),
    );

    final repoPresenterArgs = useDi
        ? <String>[]
        : _buildRepoPresenterArgs(config);
    final imports = _buildImports(config, domainSnake, useDi);
    imports.addAll(additionalImports);

    final effectiveEntityName = config.usesCustomVpc
        ? config.effectivePresenterName.replaceAll('Presenter', '')
        : entityName;

    final hasList =
        config.methods.contains('getList') ||
        config.methods.contains('watchList');
    final initialMethod = hasList
        ? (config.methods.contains('watchList') ? 'watchList' : 'getList')
        : (config.methods.contains('get') || config.methods.contains('watch')
              ? (config.methods.contains('watch') ? 'watch' : 'get')
              : null);

    final initialMethodCall = initialMethod != null
        ? _buildNamedInitialMethodCall(
            config,
            effectiveEntityName,
            initialMethod,
          )
        : Block((b) => b);

    final isCustom =
        (args['capability'] ?? '') == 'custom' ||
        (!config.generateVpcs &&
            !config.generateController &&
            !config.generatePresenter &&
            !config.isEntityBased &&
            !config.isOrchestrator);

    final isStateful =
        isCustom &&
        (config.generateState ||
            (await fs.exists(filePath) &&
                (await fs.read(filePath)).contains('StatefulWidget')));

    final content = classBuilder.build(
      ViewClassSpec(
        viewName: viewName,
        controllerName: controllerName,
        presenterName: presenterName,
        entityName: config.noEntity ? null : entityName,
        entityCamel: config.noEntity ? null : config.nameCamel,
        repoFields: repoFields,
        routeFields: routeFields,
        customParameters: customParameters,
        repoPresenterArgs: repoPresenterArgs,
        initialMethodCall: initialMethodCall,
        imports: imports,
        withState: config.generateState || config.customStateName != null,
        isCustom: isCustom,
        isStateful: isStateful,
        stateClassName: config.effectiveStateName,
        withXRay: config.generateXRay,
      ),
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'view',
      force: true, // Force when registering
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
      fileSystem: fs,
    );

    return [file];
  }

  List<Field> _buildRouteFieldsForView(GeneratorConfig config, bool isDetail) {
    final fields = <Field>[];

    final withState = config.generateState || config.customStateName != null;
    // #328: Always accept the entity named-param when the entity is
    // CRUD-backed (`isEntityBased`), so the route generator's
    // `View(entityCamel: state.extra as Entity?)` call compiles even without
    // --state. Previously this field was only emitted under --state, so the
    // route's named-arg had no matching constructor parameter and analyze
    // flagged `extra_positional_arguments` / undefined named-param. The
    // field stays optional (not `required`), so non-route call sites that
    // construct the view without the entity still compile.
    if (!config.noEntity && (withState || config.isEntityBased)) {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer('${config.name}?')
            ..name = config.nameCamel,
        ),
      );
    }

    final hasListMethods =
        config.methods.contains('getList') ||
        config.methods.contains('watchList');
    final isOnlyView = !hasListMethods && !isDetail;

    if (isDetail || (isOnlyView && _needsIdParam(config))) {
      if (config.queryField != config.idField &&
          config.queryFieldType != 'NoParams') {
        fields.add(
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer(_nullableType(config.queryFieldType))
              ..name = config.queryField,
          ),
        );
      } else {
        fields.add(
          Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer(_nullableType(config.idFieldType))
              ..name = config.idField,
          ),
        );
      }
    } else if (_needsQueryParam(config)) {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(_nullableType(config.queryFieldType))
            ..name = config.queryField,
        ),
      );
    }
    return fields;
  }

  Block _buildNamedInitialMethodCall(
    GeneratorConfig config,
    String entityName,
    String method,
  ) {
    if (method == 'getList') {
      return Block(
        (b) => b
          ..statements.add(
            refer(
              'controller',
            ).property('get${entityName}List').call([]).statement,
          ),
      );
    }
    if (method == 'watchList') {
      return Block(
        (b) => b
          ..statements.add(
            refer(
              'controller',
            ).property('watch${entityName}List').call([]).statement,
          ),
      );
    }
    if (method == 'get') {
      return _buildSingleCall(
        config: config,
        entityName: entityName,
        methodName: 'get',
      );
    }
    if (method == 'watch') {
      return _buildSingleCall(
        config: config,
        entityName: entityName,
        methodName: 'watch',
      );
    }
    return Block((b) => b);
  }

  List<String> _buildImports(
    GeneratorConfig config,
    String domainSnake,
    bool useDi,
  ) {
    final relativePath = '../../';
    final imports = <String>['package:flutter/material.dart'];

    final isCustom =
        !config.generateVpcs &&
        !config.generateController &&
        !config.generatePresenter &&
        !config.isEntityBased &&
        !config.isOrchestrator;

    if (!isCustom) {
      // #284/#281: Presentation layer imports `zuraffa_flutter` (which
      // re-exports `zuraffa` + Flutter-specific CleanView/CleanViewState/
      // ControlledWidgetBuilder types) instead of `zuraffa` alone.
      imports.add('package:zuraffa_flutter/zuraffa_flutter.dart');

      if (!useDi) {
        for (final repo in config.effectiveRepos) {
          final repoSnake = StringUtils.camelToSnake(
            repo.replaceAll('Repository', ''),
          );
          imports.add(
            '$relativePath../domain/repositories/${repoSnake}_repository.dart',
          );
        }
      }

      final controllerSnake = StringUtils.camelToSnake(
        config.effectiveControllerName.replaceAll('Controller', ''),
      );
      final presenterSnake = StringUtils.camelToSnake(
        config.effectivePresenterName.replaceAll('Presenter', ''),
      );

      imports.add('${controllerSnake}_controller.dart');
      imports.add('${presenterSnake}_presenter.dart');

      final withState = config.generateState || config.customStateName != null;
      // #328: Import the entity whenever the view's constructor accepts it
      // (CRUD-backed or --state). Must match the field condition in
      // _buildRouteFieldsForView, otherwise the field's type
      // (`${config.name}?`) references an unimported symbol.
      if (!config.noEntity && (withState || config.isEntityBased)) {
        final entitySnake = config.nameSnake;
        imports.add(
          '$relativePath../domain/entities/$entitySnake/$entitySnake.dart',
        );
      }

      if (config.generateState) {
        final stateSnake = config.nameSnake;
        imports.add('${stateSnake}_state.dart');
      } else if (config.customStateName != null) {
        final stateSnake = StringUtils.camelToSnake(
          config.customStateName!.replaceAll('State', ''),
        );
        imports.add('${stateSnake}_state.dart');
      }
    }

    return imports;
  }

  List<Field> _buildRepoFields(GeneratorConfig config) {
    return config.effectiveRepos
        .map(
          (repo) => Field(
            (f) => f
              ..modifier = FieldModifier.final$
              ..type = refer(repo)
              ..name = StringUtils.pascalToCamel(repo),
          ),
        )
        .toList();
  }

  List<String> _buildRepoPresenterArgs(GeneratorConfig config) {
    return config.effectiveRepos.map((repo) {
      final repoCamel = StringUtils.pascalToCamel(repo);
      return '$repoCamel: $repoCamel';
    }).toList();
  }

  bool _needsIdParam(GeneratorConfig config) {
    final hasGet = config.methods.contains('get');
    final hasWatch = config.methods.contains('watch');
    final hasUpdate = config.methods.contains('update');
    final hasDelete = config.methods.contains('delete');
    return hasGet || hasWatch || hasUpdate || hasDelete;
  }

  bool _needsQueryParam(GeneratorConfig config) {
    final hasGet = config.methods.contains('get');
    final hasWatch = config.methods.contains('watch');
    final needsIdParam = _needsIdParam(config);

    if (needsIdParam) {
      return false;
    }

    if (config.queryFieldType == 'NoParams') {
      return false;
    }
    return (hasGet || hasWatch) && config.queryField != config.idField;
  }

  Block _buildSingleCall({
    required GeneratorConfig config,
    required String entityName,
    required String methodName,
  }) {
    if (config.queryFieldType == 'NoParams') {
      return Block(
        (b) => b
          ..statements.add(
            refer(
              'controller',
            ).property('$methodName$entityName').call([]).statement,
          ),
      );
    }

    if (_needsIdParam(config)) {
      final fieldName =
          (config.queryField != config.idField &&
              config.queryFieldType != 'NoParams')
          ? config.queryField
          : config.idField;
      final idValue = refer('widget').property(fieldName);
      return Block(
        (b) => b
          ..statements.add(
            idValue
                .notEqualTo(literalNull)
                .conditional(
                  refer('controller').property('$methodName$entityName').call([
                    idValue.nullChecked,
                  ]),
                  literalNull,
                )
                .statement,
          ),
      );
    }

    if (_needsQueryParam(config)) {
      final queryValue = refer('widget').property(config.queryField);
      return Block(
        (b) => b
          ..statements.add(
            queryValue
                .notEqualTo(literalNull)
                .conditional(
                  refer('controller').property('$methodName$entityName').call([
                    queryValue.nullChecked,
                  ]),
                  literalNull,
                )
                .statement,
          ),
      );
    }
    return Block((b) => b);
  }

  String _nullableType(String type) {
    if (type.endsWith('?')) {
      return type;
    }
    return '$type?';
  }
}
