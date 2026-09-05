import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/di/capabilities/verify_capability.dart';
import '../plugins/di/di_plugin.dart';
import '../plugins/tdd/models/verdict_envelope.dart';

/// `zfa di verify [--json]` — the DI dangling-binding gate (spec #974),
/// now with the canonical machine verdict (SPEC 1106, issue #1106).
///
/// The gate resolves every `getIt<T>()` / `getIt.registerXxx<T>()` call
/// in the registrations under `<outputDir>/di/` against classes on disk;
/// a dangling binding fails the verdict with a `--> fix:` hint. With
/// `--json` it emits exactly one parseable `verdict.v1` envelope as the
/// LAST stdout line — `{schema, command, verdict, exit_class, subject,
/// findings, drifts, details, timestamp}` with `subject: {kind: "di"}`,
/// `findings: [{kind, file, member, fix}]` and
/// `details: {danglingClasses[], deadImports[]}` — and no prose.
///
/// Registered manually on [ModularDiCommand] (the `manualSubcommandNames`
/// hook, issue #761) rather than auto-derived from the capability: the
/// generic `CapabilityCommand` already owns `--json` as *JSON input*,
/// and for this command `--json` must select *JSON output* — the same
/// seam `cache verify`, `route verify` and `provider verify` already
/// took.
class DiVerifyCommand extends Command<void> {
  final DiPlugin plugin;

  /// Project root the class index resolves from. Defaults to the current
  /// working directory (the CLI contract); injectable so tests can point
  /// at a temp fixture.
  final String? projectRoot;

  DiVerifyCommand(this.plugin, {this.projectRoot}) {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a single canonical verdict.v1 envelope on stdout '
          '(CI-able, SPEC 1106).',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview the gate verdict as a plan report without executing',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify DI registrations resolve against classes on disk '
      '(dangling bindings fail with a fix hint)';

  @override
  Future<void> run() async {
    final capability = DiVerifyCapability(plugin, projectRoot: projectRoot);
    final jsonMode = argResults?['json'] == true;

    if (argResults?['dry-run'] == true) {
      final report = await capability.plan(const {});
      print(jsonEncode(report.toJson()));
      return;
    }

    final result = await capability.execute(const {});

    if (jsonMode) {
      // No prose: agents/CI consume stdout directly. Exactly one
      // canonical envelope as the last (and only) stdout line.
      final data = result.data ?? const <String, dynamic>{};
      final rawFindings = (data['findings'] as List?) ?? const <dynamic>[];
      final findings = rawFindings
          .whereType<Map<String, dynamic>>()
          .map(
            (f) => <String, Object?>{
              'kind': f['kind'] as String?,
              'file': f['file'] as String?,
              'member': (f['member'] ?? f['class']) as String?,
              'fix': f['fix'] as String?,
            },
          )
          .toList();
      final drifts = rawFindings
          .whereType<Map<String, dynamic>>()
          .map((f) => '${f['file']}: ${f['detail']}')
          .toList(growable: false);
      final deadImports = findings
          .where((f) => f['kind'] == 'dangling import')
          .map((f) => f['member'])
          .toList();
      final danglingClasses = findings
          .where((f) => f['kind'] == 'dangling binding')
          .map((f) => f['member'])
          .toList();
      final ok = result.success;
      VerdictEnvelope.emit(
        command: 'di verify',
        outcome: ok ? VerdictOutcome.pass : VerdictOutcome.fail,
        exitClass: ok ? 'ok' : 'fail',
        subject: <String, Object?>{
          'kind': 'di',
          'entity': '${plugin.outputDir}/di',
        },
        findings: findings,
        drifts: drifts,
        details: <String, Object?>{
          'danglingClasses': danglingClasses,
          'deadImports': deadImports,
          'filesScanned': data['files_scanned'] ?? 0,
          'bindingsChecked': data['bindings_checked'] ?? 0,
        },
      );
      exitCode = ok ? 0 : 1;
      return;
    }

    // Text path — byte-identical to the pre-1106 CapabilityCommand runner.
    if (result.success) {
      if (result.message != null) {
        print('✅ ${result.message}');
      }
      exitCode = 0;
    } else {
      print('❌ Failed: ${result.message}');
      exitCode = 1;
    }
  }
}
