import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/view_command.dart';
import '../../core/generator_options.dart';
import '../../core/plugin_system/capability.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/view_class_builder.dart';
import 'capabilities/create_view_capability.dart';
import 'capabilities/custom_view_capability.dart';

/// Generates Flutter view classes for presentation pages.
///
/// Produces view widgets wired to controllers and presenters, with optional
/// state integration and route argument handling.
///
/// Example:
/// ```dart
/// final plugin = ViewPlugin(
///   outputDir: 'lib/src',
///   options: const GeneratorOptions(force: true),
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class ViewPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final GeneratorOptions options;
  final ViewClassBuilder classBuilder;

  /// Creates a [ViewPlugin].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param options Generation flags for writing behavior and logging.
  /// @param dryRun Deprecated: use [options].
  /// @param force Deprecated: use [options].
  /// @param verbose Deprecated: use [options].
  /// @param classBuilder Optional view class builder override.
  ViewPlugin({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.classBuilder = const ViewClassBuilder(),
  });

  @override
  List<ZuraffaCapability> get capabilities => [
    CreateViewCapability(this),
    CustomViewCapability(this),
  ];

  /// @returns Plugin identifier.
  @override
  String get id => 'view';

  /// @returns Plugin display name.
  @override
  String get name => 'View Plugin';

  /// @returns Plugin version string.
  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => ViewCommand(this);

  /// Generates view files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated view files.
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generateView || config.generateVpcs)) {
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
      );
      return delegator.generate(config);
    }

    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final viewName = '${entityName}View';
    final controllerName = config.effectiveControllerName;
    final presenterName = config.effectivePresenterName;
    final fileName = '${entitySnake}_view.dart';

    final domainSnake = config.effectiveDomain;
    final viewDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      domainSnake,
    );
    final filePath = path.join(viewDirPath, fileName);

    final useDi = config.generateDi && !config.usesCustomVpc;
    final repoFields = useDi ? <Field>[] : _buildRepoFields(config);
    final routeFields = _buildRouteFields(config);
    final repoPresenterArgs = useDi
        ? <String>[]
        : _buildRepoPresenterArgs(config);
    final imports = _buildImports(config, domainSnake, useDi);
    final effectiveEntityName = config.usesCustomVpc
        ? config.effectivePresenterName.replaceAll('Presenter', '')
        : entityName;
    final initialMethodCall = _buildInitialMethodCall(
      config,
      effectiveEntityName,
    );

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
        entityName: entityName,
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

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'view',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      skipRevertIfExisted: true,
    );
    return [file];
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

  List<Field> _buildRouteFields(GeneratorConfig config) {
    final needsIdParam = _needsIdParam(config);
    final needsQueryParam = _needsQueryParam(config);
    final fields = <Field>[];

    if (needsIdParam) {
      fields.add(
        Field(
          (f) => f
            ..modifier = FieldModifier.final$
            ..type = refer(_nullableType(config.idFieldType))
            ..name = config.idField,
        ),
      );
    }

    if (needsQueryParam) {
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

    // If we have any method that needs an ID, we use idField
    if (needsIdParam) {
      return false;
    }

    if (config.queryFieldType == 'NoParams') {
      return false;
    }
    return (hasGet || hasWatch) && config.queryField != config.idField;
  }

  Block _buildInitialMethodCall(GeneratorConfig config, String entityName) {
    if (config.methods.contains('getList')) {
      return Block(
        (b) => b
          ..statements.add(
            refer(
              'controller',
            ).property('get${entityName}List').call([]).statement,
          ),
      );
    }
    if (config.methods.contains('watchList')) {
      return Block(
        (b) => b
          ..statements.add(
            refer(
              'controller',
            ).property('watch${entityName}List').call([]).statement,
          ),
      );
    }
    if (config.methods.contains('get')) {
      return _buildSingleCall(
        config: config,
        entityName: entityName,
        methodName: 'get',
      );
    }
    if (config.methods.contains('watch')) {
      return _buildSingleCall(
        config: config,
        entityName: entityName,
        methodName: 'watch',
      );
    }
    return Block((b) => b);
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

    // Check if we use idField (get/watch/update/delete)
    if (_needsIdParam(config)) {
      final idValue = refer('widget').property(config.idField);
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

    // Check if we use queryField
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
