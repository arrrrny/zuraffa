import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/project/project_root.dart';
import '../engine/engine_checker.dart';
import '../engine/engine_receipt_writer.dart';

/// `zfa engine` — engine-slice tooling (spec 1002).
///
/// `zfa engine check <Entity>` resolves every `getIt<T>()` call in the
/// generated engine against generated classes and fails with `--> fix:`
/// on any dangling reference. Exit 0 when the engine slice is fully
/// wired; exit 1 when any finding fires.
class EngineCommand extends Command<void> {
  EngineCommand() {
    addSubcommand(EngineCheckCommand());
  }

  @override
  String get name => 'engine';

  @override
  String get description =>
      'Engine-slice tools (spec 1002): verify generated engine wiring.';

  @override
  String get invocation => 'zfa engine check <Entity> [options]';
}

class EngineCheckCommand extends Command<void> {
  EngineCheckCommand() {
    argParser.addOption(
      'format',
      help: 'Output format: text, json',
      defaultsTo: 'text',
    );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Resolve every getIt<T>() call in the generated engine; fail with '
      '--> fix: on dangling references.';

  @override
  String get invocation => 'zfa engine check <Entity> [options]';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print('❌ Usage: zfa engine check <Entity> [options]');
      print('Example: zfa engine check Login');
      exitCode = 64;
      return;
    }
    final entity = rest.first;
    final format = (argResults?['format'] as String?) ?? 'text';
    final projectRoot = ProjectRoot.find();

    // The requested method set for mock certification comes from the
    // engine receipt when one exists (the make run recorded it).
    final receipt = EngineReceiptWriter.loadReceipt(projectRoot);
    final receiptTarget = receipt?['target'] as String?;
    List<String>? methods;
    if (receipt != null && receiptTarget == entity) {
      final recorded = receipt['methods'] as List?;
      if (recorded != null) {
        methods = recorded
            .map((entry) => (entry as Map)['method'] as String)
            .toList();
      }
    }

    final result = await EngineChecker.check(
      entity: entity,
      projectRoot: projectRoot,
      methods: methods,
    );

    if (format == 'json') {
      print(
        jsonEncode({
          'entity': result.entity,
          'passed': result.passed,
          'getit_types': result.resolutions.length,
          'getit_types_resolved': result.resolvedTypes.length,
          'mock_certified': result.mockCertification?.certified,
          'failures': [for (final failure in result.failures) failure.toJson()],
        }),
      );
    } else {
      print(_renderText(result));
    }

    exitCode = result.passed ? 0 : 1;
  }

  String _renderText(EngineCheckResult result) {
    final buffer = StringBuffer();
    buffer.writeln(
      '🔍 Engine check: ${result.entity} '
      '(${result.resolutions.length} getIt lookups, '
      '${result.resolvedTypes.length} resolved)',
    );
    for (final resolution in result.resolutions) {
      final target = resolution.diRegistrationFile ?? resolution.declaringFile;
      buffer.writeln(
        '  ${resolution.resolved ? "✅" : "❌"} '
        'getIt<${resolution.typeName}> (${target ?? "dangling"})',
      );
    }
    if (result.mockCertification != null) {
      for (final entry in result.mockCertification!.methods.entries) {
        buffer.writeln(
          '  ${entry.value ? "✅" : "❌"} mock ${entry.key} '
          '${entry.value ? "certified" : "uncertified"}',
        );
      }
    }
    if (result.failures.isEmpty) {
      buffer.writeln('✅ Engine check passed for "${result.entity}".');
    } else {
      buffer.writeln(
        '❌ Engine check failed for "${result.entity}" '
        '(${result.failures.length} finding(s)):',
      );
      for (final failure in result.failures) {
        buffer.writeln('❌ ${failure.message}');
      }
    }
    return buffer.toString();
  }
}
