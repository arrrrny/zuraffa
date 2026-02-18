import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;
import 'package:analyzer/dart/ast/ast.dart' as analyzer;

import '../../commands/controller_command.dart';
import '../../core/ast/append_executor.dart';
import '../../core/ast/strategies/append_strategy.dart';
import '../../core/ast/ast_modifier.dart';
import '../../core/ast/file_parser.dart';
import '../../core/ast/node_finder.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_action.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/controller_class_builder.dart';
import 'capabilities/create_controller_capability.dart';

part 'controller_plugin_bodies.dart';
part 'controller_plugin_methods.dart';
part 'controller_plugin_utils.dart';

/// Generates controller classes for the presentation layer.
///
/// Builds controller classes that wire presenters and optional state for
/// entity screens and VPC flows.
///
/// Example:
/// ```dart
/// final plugin = ControllerPlugin(
///   outputDir: 'lib/src',
///   dryRun: false,
///   force: true,
///   verbose: false,
/// );
/// final files = await plugin.generate(GeneratorConfig(name: 'Product'));
/// ```
class ControllerPlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ControllerClassBuilder classBuilder;
  final FileParser fileParser;

  /// Creates a [ControllerPlugin].
  ///
  /// @param outputDir Target directory for generated files.
  /// @param dryRun If true, files are not written.
  /// @param force If true, existing files are overwritten.
  /// @param verbose If true, logs progress to stdout.
  /// @param classBuilder Optional class builder override.
  /// @param fileParser Optional file parser override.
  ControllerPlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ControllerClassBuilder? classBuilder,
    FileParser? fileParser,
  })  : classBuilder = classBuilder ?? const ControllerClassBuilder(),
        fileParser = fileParser ?? const FileParser();

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateControllerCapability(this),
      ];

  /// @returns Plugin identifier.
  @override
  String get id => 'controller';

  /// @returns Plugin display name.
  @override
  String get name => 'Controller Plugin';

  /// @returns Plugin version string.
  @override
  String get version => '1.0.0';

  @override
  Command createCommand() => ControllerCommand(this);

  @override
  Future<List<GeneratedFile>> create(GeneratorConfig config) =>
      _dispatch(config, PluginAction.create);

  @override
  Future<List<GeneratedFile>> delete(GeneratorConfig config) =>
      _dispatch(config, PluginAction.delete);

  @override
  Future<List<GeneratedFile>> add(GeneratorConfig config) =>
      _dispatch(config, PluginAction.add);

  @override
  Future<List<GeneratedFile>> remove(GeneratorConfig config) =>
      _dispatch(config, PluginAction.remove);

  Future<List<GeneratedFile>> _dispatch(
    GeneratorConfig config,
    PluginAction action,
  ) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = ControllerPlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        classBuilder: classBuilder,
        fileParser: fileParser,
      );
      return delegator._dispatch(config, action);
    }

    switch (action) {
      case PluginAction.create:
        return generate(config);
      case PluginAction.delete:
        return _delete(config);
      case PluginAction.add:
        return _add(config);
      case PluginAction.remove:
        return _remove(config);
    }
  }

  /// Generates controller files for the given [config].
  ///
  /// @param config Generator configuration describing the entity and options.
  /// @returns List of generated controller files.
  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (!(config.generateController || config.generateVpcs)) {
      return [];
    }

    // Delegator logic removed here as it is handled in _dispatch
    // But kept for direct generate() calls just in case
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = ControllerPlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        classBuilder: classBuilder,
        fileParser: fileParser,
      );
      return delegator.generate(config);
    }

    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);
    final controllerName = '${entityName}Controller';
    final presenterName = '${entityName}Presenter';
    final stateName = '${entityName}State';

    final withState = config.generateState;

    final methods = _buildMethods(
      config,
      entityName,
      entityCamel,
      withState,
    );

    final imports = _buildImports(config, entitySnake, withState);

    final filePath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
      '${entitySnake}_controller.dart',
    );

    final content = classBuilder.build(
      ControllerClassSpec(
        className: controllerName,
        presenterName: presenterName,
        stateClassName: withState ? stateName : null,
        withState: withState,
        methods: methods,
        imports: imports,
      ),
    );

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'controller',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      revert: config.revert,
    );
    return [file];
  }

  Future<List<GeneratedFile>> _delete(GeneratorConfig config) async {
    final entitySnake = StringUtils.camelToSnake(config.name);
    final filePath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
      '${entitySnake}_controller.dart',
    );
    final file = File(filePath);

    if (!file.existsSync()) {
      return [];
    }

    if (!dryRun) {
      await file.delete();
    }

    return [
      GeneratedFile(path: filePath, type: 'controller', action: 'deleted'),
    ];
  }

  Future<List<GeneratedFile>> _add(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);

    final filePath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
      '${entitySnake}_controller.dart',
    );

    if (!File(filePath).existsSync()) {
      return [];
    }

    final parseResult = await fileParser.parseFile(filePath);
    if (parseResult.unit == null) return [];

    final className = '${entityName}Controller';
    final classNode = NodeFinder.findClass(parseResult.unit!, className);
    if (classNode == null) return [];

    // Generate methods first to know their names
    final generatedMethods = _buildMethods(
      config,
      entityName,
      entityCamel,
      config.generateState,
    );

    final existingMethodNames = classNode.members
        .whereType<analyzer.MethodDeclaration>()
        .map((m) => m.name.lexeme)
        .toSet();

    if (verbose) {
      print('ControllerPlugin: Existing methods: $existingMethodNames');
      print('ControllerPlugin: Config methods: ${config.methods}');
    }

    final methodsToAppend = generatedMethods
        .where((m) => m.name != null && !existingMethodNames.contains(m.name!))
        .toList();

    if (verbose) {
      print('ControllerPlugin: Methods to append: ${methodsToAppend.map((m) => m.name).toList()}');
    }

    if (methodsToAppend.isEmpty) return [];

    var source = await File(filePath).readAsString();
    final originalSource = source;
    final executor = AppendExecutor();
    final emitter = DartEmitter();

    for (final method in methodsToAppend) {
      final methodSource = method.accept(emitter).toString();
      final result = executor.execute(AppendRequest.method(
        source: source,
        className: className,
        memberSource: methodSource,
      ));
      if (result.changed) source = result.source;
    }

    if (source != originalSource) {
      await FileUtils.writeFile(
        filePath,
        source,
        'controller',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        revert: config.revert,
      );
      return [GeneratedFile(path: filePath, type: 'controller', action: 'updated')];
    }
    return [];
  }

  Future<List<GeneratedFile>> _remove(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = StringUtils.camelToSnake(entityName);
    final entityCamel = StringUtils.pascalToCamel(entityName);

    final filePath = path.join(
      outputDir,
      'presentation',
      'pages',
      entitySnake,
      '${entitySnake}_controller.dart',
    );

    if (!File(filePath).existsSync()) {
      return [];
    }

    final parseResult = await fileParser.parseFile(filePath);
    if (parseResult.unit == null) return [];

    final className = '${entityName}Controller';
    final classNode = NodeFinder.findClass(parseResult.unit!, className);
    if (classNode == null) return [];

    // Generate methods to know names to remove
    final targetMethods = _buildMethods(
      config,
      entityName,
      entityCamel,
      config.generateState,
    );
    final targetMethodNames =
        targetMethods.map((m) => m.name).whereType<String>().toSet();

    var source = await File(filePath).readAsString();
    var modified = false;

    // Find methods to remove
    final methodsToRemove = <analyzer.MethodDeclaration>[];
    for (final member in classNode.members) {
      if (member is analyzer.MethodDeclaration &&
          targetMethodNames.contains(member.name.lexeme)) {
        methodsToRemove.add(member);
      }
    }

    if (methodsToRemove.isEmpty) return [];

    // Sort by offset descending to remove safely
    methodsToRemove.sort((a, b) => b.offset.compareTo(a.offset));

    for (final method in methodsToRemove) {
      source = AstModifier.removeMethodFromClass(
        source: source,
        method: method,
      );
      modified = true;
    }

    if (modified) {
      await FileUtils.writeFile(
        filePath,
        source,
        'controller',
        force: true,
        dryRun: dryRun,
        verbose: verbose,
        revert: false, // Do not delete file when removing members
      );
      return [
        GeneratedFile(path: filePath, type: 'controller', action: 'updated'),
      ];
    }

    return [];
  }
}
