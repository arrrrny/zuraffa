import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../../models/generator_config.dart';
import '../../models/generator_result.dart';
import '../orchestration/plugin_orchestrator.dart';

class DebugArtifactSaver {
  final String projectRoot;

  DebugArtifactSaver({required this.projectRoot});

  Future<String> save({
    GeneratorConfig? config,
    required GeneratorResult result,
    List<String>? args,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final dir = Directory(path.join(projectRoot, '.zfa_debug', timestamp));
    await dir.create(recursive: true);

    final artifacts = {
      'result': result.toJson(),
      'args': args ?? const [],
      'error': error?.toString(),
      'stack': stackTrace?.toString(),
    };
    final artifactsFile = File(path.join(dir.path, 'artifacts.json'));
    await artifactsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(artifacts),
    );

    if (config != null) {
      final configFile = File(path.join(dir.path, 'config.json'));
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config.toJson()),
      );
    }

    return dir.path;
  }

  Future<String> saveOrchestration({
    GeneratorConfig? config,
    required OrchestrationResult result,
    List<String>? args,
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final dir = Directory(path.join(projectRoot, '.zfa_debug', timestamp));
    await dir.create(recursive: true);

    final artifacts = {
      'success': result.success,
      'files': result.files.map((f) => f.toJson()).toList(),
      'errors': result.errors,
      'args': args ?? const [],
      'error': error?.toString(),
      'stack': stackTrace?.toString(),
    };
    final artifactsFile = File(path.join(dir.path, 'artifacts.json'));
    await artifactsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(artifacts),
    );

    if (config != null) {
      final configFile = File(path.join(dir.path, 'config.json'));
      await configFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config.toJson()),
      );
    }

    return dir.path;
  }

  Future<String> saveSimple({
    List<String>? args,
    String? error,
    String? stackTrace,
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '');
    final dir = Directory(path.join(projectRoot, '.zfa_debug', timestamp));
    await dir.create(recursive: true);

    final artifacts = {
      'args': args ?? const [],
      'error': error,
      'stack': stackTrace,
    };
    final artifactsFile = File(path.join(dir.path, 'artifacts.json'));
    await artifactsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(artifacts),
    );

    return dir.path;
  }
}
