import 'dart:async';

import '../models/generator_config.dart';
import '../models/generator_result.dart';
import '../models/generated_file.dart';
import '../generator/code_generator.dart';
import '../core/plugin_system/capability.dart';
import '../plugins/presenter/presenter_plugin.dart';
import '../plugins/presenter/capabilities/register_presenter_capability.dart';
import '../plugins/controller/controller_plugin.dart';
import '../plugins/controller/capabilities/register_controller_capability.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/state/capabilities/register_state_capability.dart';

/// Batch command to register a use case across multiple layers.
class RegisterCommand {
  static const String fixedOutputDir = 'lib/src';

  Future<GeneratorResult> execute(List<String> args) async {
    if (args.isEmpty) {
      print('Usage: zfa register <UseCaseName> [options]');
      print('   --controller, -c       Register in Controller');
      print('   --presenter, -p        Register in Presenter');
      print('   --state, -s            Register in State');
      print('   --di, -d               Register in DI');
      print('   --all, -a              Register in all layers');
      return GeneratorResult(
        name: 'error',
        success: false,
        files: [],
        errors: ['Missing arguments'],
        nextSteps: [],
      );
    }

    final useCaseName = args[0];
    final layerFlags = _parseLayerFlags(args);
    final useAll = layerFlags['all'] == true;
    final noFlags = !layerFlags.values.any((v) => v);
    final includeController =
        useAll || noFlags || layerFlags['controller'] == true;
    final includePresenter =
        useAll || noFlags || layerFlags['presenter'] == true;
    final includeState = useAll || noFlags || layerFlags['state'] == true;
    final includeDi = useAll || noFlags || layerFlags['di'] == true;

    final domain = _extractOption(args, '--domain');
    final entity = _extractOption(args, '--entity');
    final stateType = _extractOption(args, '--state-type');
    final dryRun = args.contains('--dry-run');
    final force = args.contains('--force') || args.contains('-f');
    final verbose = args.contains('--verbose') || args.contains('-v');

    final allFiles = <GeneratedFile>[];
    final allErrors = <String>[];

    if (includeDi) {
      try {
        final diResult = await _registerInDi(
          useCaseName,
          domain: domain,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        allFiles.addAll(diResult.files);
      } catch (e) {
        allErrors.add('DI: $e');
      }
    }

    if (includePresenter) {
      try {
        final presenterResult = await _registerInPresenter(
          useCaseName,
          entity: entity,
          domain: domain,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        final generatedFiles = presenterResult.data?['generatedFiles'];
        if (generatedFiles is List<GeneratedFile>) {
          allFiles.addAll(generatedFiles);
        }
      } catch (e) {
        allErrors.add('Presenter: $e');
      }
    }

    if (includeController) {
      try {
        final controllerResult = await _registerInController(
          useCaseName,
          entity: entity,
          domain: domain,
          dryRun: dryRun,
          force: force,
          verbose: verbose,
        );
        final generatedFiles = controllerResult.data?['generatedFiles'];
        if (generatedFiles is List<GeneratedFile>) {
          allFiles.addAll(generatedFiles);
        }
      } catch (e) {
        allErrors.add('Controller: $e');
      }
    }

    if (includeState) {
      if (stateType == null && !dryRun) {
        allErrors.add('State: --state-type is required for state registration');
      } else {
        try {
          final stateResult = await _registerInState(
            useCaseName,
            fieldType: stateType ?? 'dynamic',
            entity: entity,
            domain: domain,
            dryRun: dryRun,
            force: force,
            verbose: verbose,
          );
          final generatedFiles = stateResult.data?['generatedFiles'];
          if (generatedFiles is List<GeneratedFile>) {
            allFiles.addAll(generatedFiles);
          }
        } catch (e) {
          allErrors.add('State: $e');
        }
      }
    }

    if (allErrors.isNotEmpty) {
      print('Some layers had issues:');
      for (final error in allErrors) {
        print('  - $error');
      }
    }

    return GeneratorResult(
      name: useCaseName,
      success: allErrors.isEmpty,
      files: allFiles,
      errors: allErrors,
      nextSteps: [],
    );
  }

  Future<GeneratorResult> _registerInDi(
    String useCaseName, {
    String? domain,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) async {
    final config = GeneratorConfig(
      name: useCaseName,
      outputDir: fixedOutputDir,
      domain: domain ?? 'general',
      generateDi: true,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
    );

    final generator = CodeGenerator(config: config, outputDir: fixedOutputDir);
    final result = await generator.generate();
    if (!result.success) {
      print('   DI registration had issues: ${result.errors}');
    }
    return result;
  }

  Future<ExecutionResult> _registerInPresenter(
    String useCaseName, {
    String? entity,
    String? domain,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) async {
    final plugin = PresenterPlugin(outputDir: fixedOutputDir);
    final capability = RegisterPresenterCapability(plugin);
    final args = <String, dynamic>{
      'target': useCaseName,
      'dryRun': dryRun,
      'force': force,
      'verbose': verbose,
    };
    if (entity != null) args['entity'] = entity;
    if (domain != null) args['domain'] = domain;
    return capability.execute(args);
  }

  Future<ExecutionResult> _registerInController(
    String useCaseName, {
    String? entity,
    String? domain,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) async {
    final plugin = ControllerPlugin(outputDir: fixedOutputDir);
    final capability = RegisterControllerCapability(plugin);
    final args = <String, dynamic>{
      'target': useCaseName,
      'dryRun': dryRun,
      'force': force,
      'verbose': verbose,
    };
    if (entity != null) args['entity'] = entity;
    if (domain != null) args['domain'] = domain;
    return capability.execute(args);
  }

  Future<ExecutionResult> _registerInState(
    String useCaseName, {
    required String fieldType,
    String? entity,
    String? domain,
    required bool dryRun,
    required bool force,
    required bool verbose,
  }) async {
    final plugin = StatePlugin(outputDir: fixedOutputDir);
    final capability = RegisterStateCapability(plugin);
    final args = <String, dynamic>{
      'target': useCaseName,
      'type': fieldType,
      'dryRun': dryRun,
      'force': force,
      'verbose': verbose,
    };
    if (entity != null) args['entity'] = entity;
    if (domain != null) args['domain'] = domain;
    return capability.execute(args);
  }

  Map<String, bool> _parseLayerFlags(List<String> args) {
    final flags = <String, bool>{};
    for (var i = 1; i < args.length; i++) {
      if (i == 0) continue;
      final arg = args[i];
      if (arg == '--controller' || arg == '-c') {
        flags['controller'] = true;
      } else if (arg == '--presenter' || arg == '-p') {
        flags['presenter'] = true;
      } else if (arg == '--state' || arg == '-s') {
        flags['state'] = true;
      } else if (arg == '--di' || arg == '-d') {
        flags['di'] = true;
      } else if (arg == '--all' || arg == '-a') {
        flags['all'] = true;
      }
    }
    return flags;
  }

  String? _extractOption(List<String> args, String option) {
    for (var i = 0; i < args.length - 1; i++) {
      if (args[i] == option) {
        return args[i + 1];
      }
    }
    return null;
  }
}
