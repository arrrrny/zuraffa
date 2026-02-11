import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../core/plugin_system/plugin_interface.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/view_class_builder.dart';

class ViewPlugin extends FileGeneratorPlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ViewClassBuilder classBuilder;

  ViewPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ViewClassBuilder? classBuilder,
  }) : classBuilder = classBuilder ?? const ViewClassBuilder();

  @override
  String get id => 'view';

  @override
  String get name => 'View Plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generateView || config.generateVpc)) {
      return [];
    }
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final viewName = '${entityName}View';
    final controllerName = '${entityName}Controller';
    final presenterName = '${entityName}Presenter';
    final fileName = '${entitySnake}_view.dart';

    final viewDirPath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
    );
    final filePath = path.join(viewDirPath, fileName);

    final repoFields = _buildRepoFields(config);
    final routeFields = _buildRouteFields(config);
    final repoPresenterArgs = _buildRepoPresenterArgs(config);
    final imports = _buildImports(config, entitySnake);
    final initialMethodCall = _buildInitialMethodCall(config, entityName);

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
        withState: config.generateState,
      ),
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'view',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
    );
    return [file];
  }

  List<String> _buildImports(GeneratorConfig config, String entitySnake) {
    final relativePath = '../../';
    final imports = <String>[
      'package:flutter/material.dart',
      'package:zuraffa/zuraffa.dart',
    ];

    for (final repo in config.effectiveRepos) {
      final repoSnake = StringUtils.camelToSnake(
        repo.replaceAll('Repository', ''),
      );
      imports.add(
        '$relativePath../domain/repositories/${repoSnake}_repository.dart',
      );
    }

    imports.add('${entitySnake}_controller.dart');
    imports.add('${entitySnake}_presenter.dart');
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
            ..type = refer(_nullableType(config.idType))
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
    final hasUpdate = config.methods.contains('update');
    final hasDelete = config.methods.contains('delete');
    return hasUpdate || hasDelete;
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

  Block _buildInitialMethodCall(GeneratorConfig config, String entityName) {
    if (config.methods.contains('getList')) {
      return Block(
        (b) => b
          ..statements.add(
            refer('controller').property('get${entityName}List').call([]).statement,
          ),
      );
    }
    if (config.methods.contains('watchList')) {
      return Block(
        (b) => b
          ..statements.add(
            refer('controller').property('watch${entityName}List').call([]).statement,
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
            refer('controller')
                .property('$methodName$entityName')
                .call([])
                .statement,
          ),
      );
    }
    if (_needsIdParam(config) && config.queryField == config.idField) {
      final idValue = refer('widget').property(config.idField);
      return Block(
        (b) => b
          ..statements.add(
            idValue
                .notEqualTo(literalNull)
                .conditional(
                  refer('controller')
                      .property('$methodName$entityName')
                      .call([idValue.nullChecked]),
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
                  refer('controller')
                      .property('$methodName$entityName')
                      .call([queryValue.nullChecked]),
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
