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
import 'builders/view_class_builder.dart';
import 'capabilities/create_view_capability.dart';
import 'capabilities/custom_view_capability.dart';
import 'capabilities/register_view_capability.dart';

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
      methods: context.data['methods']?.cast<String>().toList() ?? [],
      domain: context.data['domain'],
      idField: context.data['id-field'] ?? 'id',
      idFieldType: context.data['id-field-type'] ?? 'String',
      queryField: context.data['query-field'] ?? 'id',
      queryFieldType: context.data['query-field-type'],
      noEntity: context.data['no-entity'] == true,
      generateState: context.data['state'] == true,
      generateDi: context.data['di'] == true,
    );

    return generate(config, context: context);
  }

  @override
  Future<List<GeneratedFile>> generate(
    GeneratorConfig config, {
    PluginContext? context,
  }) async {
    if (!config.generateView && !config.generateVpcs && !config.revert) {
      return [];
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

      final file = await _generateViewFile(
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
      );
      generatedFiles.add(file);
    }

    if (isMasterDetail) {
      final viewName = '${entityName}DetailView';
      final fileName = '${config.nameSnake}_detail_view.dart';
      final filePath = path.join(viewDirPath, fileName);

      final file = await _generateViewFile(
        config: config,
        viewName: viewName,
        filePath: filePath,
        domainSnake: domainSnake,
        initialMethod: config.methods.contains('watch') ? 'watch' : 'get',
        fileSystem: fs,
      );
      generatedFiles.add(file);
    }

    return generatedFiles;
  }

  Future<GeneratedFile> _generateViewFile({
    required GeneratorConfig config,
    required String viewName,
    required String filePath,
    required String domainSnake,
    String? initialMethod,
    required FileSystem fileSystem,
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
        !config.isEntityBased;

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
        withState: config.generateState || config.customStateName != null,
        isCustom: isCustom,
        isStateful: isCustom && config.generateState,
        stateClassName: config.effectiveStateName,
      ),
      leadingComment: '// Generated by zfa for: ${config.name}',
    );

    return FileUtils.writeFile(
      filePath,
      content,
      'view',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
      fileSystem: fileSystem,
    );
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
            !config.isEntityBased);

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
    if (withState && !config.noEntity) {
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
        !config.isEntityBased;

    if (!isCustom) {
      imports.add('package:zuraffa/zuraffa.dart');

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
      if (withState && !config.noEntity) {
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
