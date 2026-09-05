import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/provider/provider_verifier.dart';
import '../utils/string_utils.dart';

/// Spec 979, orders 2 + 4 — `zfa provider verify <Entity>`.
///
/// The stub-escape gate: fails (exit 1) when the committed provider for
/// `<Entity>` still contains `UnimplementedError` method bodies, and when
/// the provider is missing a method its target Service interface
/// declares. Every finding prints the file, the method, and a
/// `--> fix:` line. `--json` emits the single machine verdict envelope
/// ({schema:1, ok, entity, providerFile, interface, methods[], stubCount,
/// findings[]}) per the #778 convention. Exit codes: 0 = verified clean,
/// 1 = findings, 64 = usage (no entity).
class ProviderVerifyCommand extends Command<void> {
  /// Injectable for tests (the CLI resolves the project root from the
  /// scoped working directory).
  final String? projectRoot;

  ProviderVerifyCommand({this.projectRoot}) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Emit the machine verdict envelope instead of prose.',
    );
    argParser.addOption(
      'service',
      help:
          'The Service interface the provider implements (default: '
          'derived from the receipt, then <Entity>Service).',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify a provider: no surviving UnimplementedError stub bodies '
      '(stub-escape gate) and every Service interface method implemented '
      '(conformance gate) — exit 1 with --> fix: lines otherwise '
      '(spec 979).';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print(
        '❌ Usage: zfa provider verify <Entity> [--service <Interface>] '
        '[--json]',
      );
      exitCode = 64;
      return;
    }

    final root = projectRoot ?? _cwd();
    final entity = StringUtils.convertToPascalCase(rest.first);
    final service = argResults?['service'] as String?;

    final report = await const ProviderVerifier().verify(
      projectRoot: root,
      entity: entity,
      service: service == null || service.isEmpty ? null : service,
    );

    if (argResults?['json'] == true) {
      print(jsonEncode(report.toJson()));
    } else {
      _printText(report);
    }
    exitCode = report.ok ? 0 : 1;
  }

  static String _cwd() {
    try {
      return Directory.current.path;
    } catch (_) {
      return '.';
    }
  }

  void _printText(ProviderVerifyReport report) {
    final file = report.providerFile ?? '(no provider file found)';
    print('Provider Verify — ${report.entity}');
    print('  interface: ${report.interface}');
    print('  provider : $file');
    print('  stubs    : ${report.stubCount}');
    print(
      '  findings : ${report.findings.length} '
      '(${report.conformanceFindings.length} conformance, '
      '${report.stubFindings.length} stub)',
    );
    if (report.findings.isEmpty) {
      print('✅ verified: no stubs, every interface method implemented.');
      return;
    }
    print('');
    for (final finding in report.findings) {
      final method = finding.method.isEmpty ? '' : '${finding.method}: ';
      print('  [${finding.kind}] $method${finding.detail}');
      if (finding.file.isNotEmpty) {
        print('    file: ${finding.file}');
      }
      print('    ${finding.fix}');
    }
  }
}
