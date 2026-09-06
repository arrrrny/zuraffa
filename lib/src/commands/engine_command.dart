import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/project/project_root.dart';
import '../engine/engine_checker.dart';
import '../engine/engine_receipt_writer.dart';

/// `zfa engine` — engine-slice tooling (spec 1002; legs extended by
/// issue #1109).
///
/// `zfa engine check <Entity>` runs three legs over the generated slice
/// (issue #1109 contract `specs/077-make-engine-preset/contracts/`):
///   1. static analysis — `dart analyze` scoped to the entity's
///      engine-tree files (`lib/**` + `test/**` paths containing the
///      entity snake); every finding fails the check naming the file;
///   2. receipt certification — `specs/<feature>/tdd/engine.receipt.json`
///      must exist and record no `mock_certified: false` (the
///      #1014/CERT-GATE signal);
///   3. import boundary — zero `package:flutter` imports in the engine
///      tree (the U7 boundary guard, built in since spec 1002).
///
/// Plus the spec-1002 core: every `getIt<T>()` call resolves to a
/// generated class or DI registration file. Exit 0 when the slice is
/// fully wired; exit 1 when any finding fires; 64 on usage error.
class EngineCommand extends Command<void> {
  EngineCommand() {
    addSubcommand(EngineCheckCommand());
  }

  @override
  String get name => 'engine';

  @override
  String get description =>
      'Engine-slice tools (spec 1002 + issue #1109): verify generated '
      'engine wiring, certification and static analysis.';

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
    argParser.addOption(
      'feature',
      help:
          'Feature directory holding the engine receipt '
          '(specs/<feature>/tdd/engine.receipt.json). Defaults to a '
          'scan of specs/*/tdd/ for the entity.',
    );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Static analysis + engine receipt + import boundary + getIt '
      'resolution over the generated engine slice; fail with --> fix: '
      'on any finding.';

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
    final feature = argResults?['feature'] as String?;
    final projectRoot = ProjectRoot.find();

    // The requested method set for mock certification comes from the
    // receipts when they exist (the make run recorded it) — the v2
    // receipt first (issue #1109), the .zfa/ v1 artifact as fallback.
    final v2Receipt = EngineReceiptWriter.loadV2Receipt(
      projectRoot,
      feature: feature,
      entity: entity,
    );
    final receipt = v2Receipt ?? EngineReceiptWriter.loadReceipt(projectRoot);
    final receiptTarget =
        (v2Receipt?['entity'] ?? receipt?['target']) as String?;
    List<String>? methods;
    if (receipt != null && receiptTarget == entity) {
      final recorded = receipt['methods'] as List?;
      if (recorded != null) {
        methods = recorded
            .map(
              (entry) => ((entry as Map)['name'] ?? entry['method']) as String?,
            )
            .whereType<String>()
            .toList();
      }
    }

    final result = await EngineChecker.check(
      entity: entity,
      projectRoot: projectRoot,
      methods: methods,
      feature: feature,
      verifyReceipt: true,
      runStaticAnalysis: true,
    );

    if (format == 'json') {
      print(
        jsonEncode({
          'entity': result.entity,
          'passed': result.passed,
          'getit_types': result.resolutions.length,
          'getit_types_resolved': result.resolvedTypes.length,
          'mock_certified': result.mockCertification?.certified,
          // Spec 1110: the refusal receipt path when the cert gate
          // blocked — a real exit code plus a machine-readable receipt,
          // not stdout noise.
          if (result.certGateReceiptPath != null)
            'cert_gate': {
              'blocked': true,
              'entity': result.entity,
              'refused_receipt': result.certGateReceiptPath,
            },
          'receipt': {
            'schema': v2Receipt?['schema'],
            'verified': v2Receipt != null,
          },
          'static_analysis': {
            'files_analyzed': result.analyzedFiles.length,
            'ran': result.analyzedFiles.isNotEmpty,
          },
          'failures': [for (final failure in result.failures) failure.toJson()],
        }),
      );
    } else {
      print(_renderText(result, v2Receipt));
    }

    exitCode = result.passed ? 0 : 1;
  }

  String _renderText(
    EngineCheckResult result,
    Map<String, dynamic>? v2Receipt,
  ) {
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
    // Issue #1109 leg summaries.
    if (v2Receipt != null) {
      buffer.writeln('  🧾 engine receipt v2: ${v2Receipt['schema']}');
    }
    if (result.analyzedFiles.isEmpty) {
      buffer.writeln(
        '  ⚠️ static analysis skipped (no slice files, or no '
        '.dart_tool/package_config.json — run `dart pub get`)',
      );
    } else {
      buffer.writeln(
        '  ✅ static analysis: dart analyze over '
        '${result.analyzedFiles.length} engine-tree file(s)',
      );
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
      // Spec 1110: the cert-gate refusal names its receipt — the fix
      // path is machine-checkable, not buried in prose.
      if (result.certGateReceiptPath != null) {
        buffer.writeln(
          '🧾 Cert-gate refusal receipt: ${result.certGateReceiptPath}',
        );
      }
    }
    return buffer.toString();
  }
}
