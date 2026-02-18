import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:path/path.dart' as path;

import '../../commands/service_command.dart';
import '../../core/ast/append_executor.dart';
import '../../core/ast/ast_modifier.dart';
import '../../core/ast/file_parser.dart';
import '../../core/ast/node_finder.dart';
import '../../core/ast/strategies/append_strategy.dart';
import '../../core/builder/patterns/common_patterns.dart';
import '../../core/builder/shared/spec_library.dart';
import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_action.dart';
import '../../core/plugin_system/plugin_interface.dart';
import '../../core/plugin_system/capability.dart';
import '../../models/generated_file.dart';
import '../../models/generator_config.dart';
import '../../utils/file_utils.dart';
import '../../utils/string_utils.dart';
import 'builders/service_interface_builder.dart';
import 'capabilities/create_service_capability.dart';

class ServicePlugin extends FileGeneratorPlugin implements CliAwarePlugin {
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final ServiceInterfaceBuilder interfaceBuilder;
  final FileParser fileParser;
  final AppendExecutor appendExecutor;
  final SpecLibrary specLibrary;

  ServicePlugin({
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    ServiceInterfaceBuilder? interfaceBuilder,
    FileParser? fileParser,
    AppendExecutor? appendExecutor,
    SpecLibrary? specLibrary,
  })  : interfaceBuilder = interfaceBuilder ?? const ServiceInterfaceBuilder(),
        fileParser = fileParser ?? const FileParser(),
        appendExecutor = appendExecutor ?? AppendExecutor(),
        specLibrary = specLibrary ?? const SpecLibrary();

  @override
  List<ZuraffaCapability> get capabilities => [
        CreateServiceCapability(this),
      ];

  @override
  Command createCommand() => ServiceCommand(this);

  @override
  String get id => 'service';

  @override
  String get name => 'Service Plugin';

  @override
  String get version => '1.0.0';

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
    switch (action) {
      case PluginAction.create:
        return generate(config);
      case PluginAction.delete:
        return _delete(config);
      case PluginAction.add:
        return _add(config);
      case PluginAction.remove:
        return _remove(config);
      default:
        return generate(config);
    }
  }

  @override
  Future<List<GeneratedFile>> generate(GeneratorConfig config) async {
    if (config.outputDir != outputDir ||
        config.dryRun != dryRun ||
        config.force != force ||
        config.verbose != verbose) {
      final delegator = ServicePlugin(
        outputDir: config.outputDir,
        dryRun: config.dryRun,
        force: config.force,
        verbose: config.verbose,
        interfaceBuilder: interfaceBuilder,
        fileParser: fileParser,
        appendExecutor: appendExecutor,
        specLibrary: specLibrary,
      );
      return delegator.generate(config);
    }

    if (!config.hasService) {
      return [];
    }
    final serviceSnake = config.serviceSnake;
    if (serviceSnake == null) {
      return [];
    }
    final fileName = '${serviceSnake}_service.dart';
    final filePath = path.join(outputDir, 'domain', 'services', fileName);
    final content = interfaceBuilder.build(config);

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'service',
      force: force,
      dryRun: dryRun,
      verbose: verbose,
      revert: config.revert,
    );

    return [file];
  }

  Future<List<GeneratedFile>> _delete(GeneratorConfig config) async {
    final serviceSnake = config.serviceSnake;
    if (serviceSnake == null) return [];
    
    final fileName = '${serviceSnake}_service.dart';
    final filePath = path.join(outputDir, 'domain', 'services', fileName);
    final file = File(filePath);
    
    final deletedFiles = <GeneratedFile>[];
    
    if (file.existsSync()) {
      if (!dryRun) {
        await file.delete();
      }
      deletedFiles.add(
        GeneratedFile(path: filePath, type: 'service', action: 'deleted'),
      );
    }
    
    // Also try to delete provider if it exists
    if (config.generateData) {
       final domainSnake = StringUtils.camelToSnake(config.effectiveDomain);
       final providerName = config.effectiveProvider;
       if (providerName != null) {
         final providerPath = path.join(
           outputDir,
           'data',
           'providers',
           domainSnake,
           '${serviceSnake}_provider.dart',
         );
         final providerFile = File(providerPath);
         if (providerFile.existsSync()) {
           if (!dryRun) {
             await providerFile.delete();
           }
           deletedFiles.add(
             GeneratedFile(
               path: providerPath, 
               type: 'provider', 
               action: 'deleted',
             ),
           );
         }
       }
    }
    
    return deletedFiles;
  }

  Future<List<GeneratedFile>> _add(GeneratorConfig config) async {
    final updatedFiles = <GeneratedFile>[];
    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    if (serviceName == null || serviceSnake == null) {
      return [];
    }

    final servicePath = path.join(
      outputDir,
      'domain',
      'services',
      '${serviceSnake}_service.dart',
    );

    if (File(servicePath).existsSync()) {
      var source = await File(servicePath).readAsString();
      
      final methodsToAdd = config.methods.isNotEmpty
          ? config.methods
          : [config.getServiceMethodName()];

      var changed = false;
      for (final methodName in methodsToAdd) {
        final result = await _appendMethodToInterface(
          config,
          source,
          serviceName,
          methodName,
        );
        if (result != null) {
          source = result;
          changed = true;
        }
      }

      if (changed) {
        await FileUtils.writeFile(
          servicePath,
          source,
          'append',
          force: true,
          dryRun: dryRun,
          verbose: verbose,
        );
        updatedFiles.add(
          GeneratedFile(path: servicePath, type: 'service', action: 'updated'),
        );
      }
    }

    // Append to Provider if exists
    if (config.generateData) {
      // TODO: Implement provider appending
    }

    return updatedFiles;
  }

  Future<String?> _appendMethodToInterface(
    GeneratorConfig config,
    String source,
    String className,
    String methodName,
  ) async {
    final paramsType = config.paramsType ?? 'NoParams';
    final returnsType = config.returnsType ?? 'void';
    
    final returnSignature = _returnSignature(config, returnsType);
    final params = paramsType == 'NoParams'
        ? const <Parameter>[]
        : [
            Parameter(
              (p) => p
                ..name = 'params'
                ..type = refer(paramsType),
            ),
          ];

    final method = CommonPatterns.abstractMethod(
      name: methodName,
      returnType: returnSignature,
      parameters: params,
    );

    final memberSource = specLibrary.emitSpec(method);
    final request = AppendRequest.method(
      source: source,
      className: className,
      memberSource: memberSource,
    );

    final result = appendExecutor.execute(request);
    return result.changed ? result.source : null;
  }

  String _returnSignature(GeneratorConfig config, String returnsType) {
    switch (config.useCaseType) {
      case 'stream':
        return 'Stream<$returnsType>';
      case 'completable':
        return 'Future<void>';
      case 'sync':
        return returnsType;
      default:
        return 'Future<$returnsType>';
    }
  }

  Future<List<GeneratedFile>> _remove(GeneratorConfig config) async {
    final serviceName = config.effectiveService;
    final serviceSnake = config.serviceSnake;
    if (serviceName == null || serviceSnake == null) {
      return [];
    }
    
    final methodsToRemove = config.methods.isNotEmpty
        ? config.methods
        : [config.getServiceMethodName()];
    
    final updatedFiles = <GeneratedFile>[];
    
    // Remove from Service Interface
    final servicePath = path.join(
      outputDir,
      'domain',
      'services',
      '${serviceSnake}_service.dart',
    );
    
    if (File(servicePath).existsSync()) {
      var source = await File(servicePath).readAsString();
      var changed = false;

      // We need to parse the file to find methods, but since we are modifying it,
      // it might be better to just use AstModifier on the source string iteratively
      // IF we can reliably find the method. 
      // AstModifier.removeMethodFromClass takes a MethodDeclaration.
      // So we need to parse.
      
      // Since parsing is expensive and we might modify the file multiple times,
      // let's try to do it one by one or batch it.
      // For simplicity, let's do one by one, re-parsing if needed, or better:
      // Since AstModifier works on offsets, we can't reuse the parsed unit after modification.
      // We must re-parse or use a regex/string approach if AstModifier is too heavy.
      // But we want to be safe.
      
      // Let's loop and re-parse. It's slower but safer.
      for (final methodName in methodsToRemove) {
        final result = await _removeMethodFromFile(
          servicePath, 
          serviceName, 
          methodName,
          currentSource: source,
        );
        if (result != null) {
          source = result;
          changed = true;
        }
      }
      
      if (changed) {
        await FileUtils.writeFile(
          servicePath,
          source,
          'remove',
          force: true,
          dryRun: dryRun,
          verbose: verbose,
        );
        updatedFiles.add(GeneratedFile(path: servicePath, type: 'interface', action: 'updated'));
      }
    }
    
    // Remove from Provider if exists
    // TODO: Implement provider removal
    
    return updatedFiles;
  }

  Future<String?> _removeMethodFromFile(
    String filePath,
    String className,
    String methodName, {
    String? currentSource,
  }) async {
    final source = currentSource ?? await File(filePath).readAsString();
    final parseResult = await fileParser.parseSource(source);
    if (parseResult.unit == null) return null;
    
    final classNode = NodeFinder.findClass(parseResult.unit!, className);
    if (classNode == null) return null;
    
    final methods = NodeFinder.findMethods(classNode, name: methodName);
    if (methods.isEmpty) return null;
    
    final method = methods.first;
    return AstModifier.removeMethodFromClass(
      source: source,
      method: method,
    );
  }
}
