import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/provider/provider_verifier.dart';
import '../utils/string_utils.dart';
import '../cli/exit_protocol.dart';

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
    argParser.addFlag(
      'explain',
      negatable: false,
      help:
          'Emit a human-readable explanation block: registered methods, '
          'resolved types, and the verdict with --> fix: hints. '
          'Suppressed when --json is also passed (the --json envelope '
          'shape is unchanged). Spec 1128 order 1.',
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
      exitCode = ExitProtocol.usage;
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
    } else if (argResults?['explain'] == true) {
      _printExplain(report);
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

  /// Spec 1128 (order 1) — `--explain` presentation path.
  ///
  /// Emits a human-readable block derived entirely from the existing
  /// [ProviderVerifyReport] fields (no new AST traversal, no schema
  /// change). The block names the entity under verification, the resolved
  /// Service interface, the provider file, the methods registered on the
  /// provider class (the AST scan), the verdict, and every `--> fix:`
  /// hint when there are findings. Suppressed when `--json` is also
  /// passed (the machine envelope shape is the single source of truth
  /// for CI consumers — spec 1128 hard constraint).
  void _printExplain(ProviderVerifyReport report) {
    final file = report.providerFile ?? '(no provider file found)';
    print('Provider Verify — Explain — ${report.entity}');
    print('  entity        : ${report.entity}');
    print('  interface     : ${report.interface}');
    print('  provider file : $file');
    // Registered methods — the interface method set (what the provider
    // is expected to mirror). Surviving stubs are flagged inline so a
    // reader sees which methods exist but are not yet filled.
    final stubs = report.stubFindings.map((f) => f.method).toSet();
    if (report.methods.isEmpty) {
      print('  methods       : (none resolved — interface file not found)');
    } else {
      print('  methods       : ${report.methods.length} registered');
      for (final method in report.methods) {
        final marker = stubs.contains(method) ? ' [STUB]' : '';
        print('    - $method$marker');
      }
    }
    print('  stub count    : ${report.stubCount}');
    // Verdict line.
    if (report.ok) {
      print(
        '  verdict       : ✅ verified — no stubs, every interface '
        'method implemented.',
      );
    } else {
      print(
        '  verdict       : ❌ not verified — '
        '${report.findings.length} finding(s).',
      );
    }
    // --> fix: hints (when present). Each finding carries its own fix line.
    if (report.findings.isEmpty) return;
    print('');
    print('  hints:');
    for (final finding in report.findings) {
      final method = finding.method.isEmpty ? '' : '${finding.method}: ';
      print('    [${finding.kind}] $method${finding.detail}');
      if (finding.file.isNotEmpty) {
        print('      file: ${finding.file}');
      }
      print('      ${finding.fix}');
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
