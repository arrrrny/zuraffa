import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/plugin_system/capability.dart';
import '../plugins/di/capabilities/verify_capability.dart';
import '../plugins/di/di_plugin.dart';

/// `zfa di verify <Entity> [--json]` — the dangling-`getIt<T>()` gate
/// (spec #974), now shipping the canonical `zuraffa.verdict.v1` JSON
/// envelope (issue #1108).
///
/// Why this is a manual subcommand (mirrors `CacheVerifyCommand`): the
/// generic `CapabilityCommand` already owns `--json` as *JSON input*
/// (issue #778), but for a verify gate `--json` must select *JSON
/// output*. Registration on `ModularDiCommand` skips the auto-derived
/// `CapabilityCommand` through `manualSubcommandNames` (the #761
/// duplicate-registration hook) and adds this command instead.
///
/// The verification itself lives in [DiVerifyCapability] — the single
/// source of truth; this command only shapes the output. `--json` emits
/// exactly one parseable envelope line and no prose (#778 convention —
/// agents/CI consume stdout directly):
///
/// ```
/// {schema, command, verdict, exit_class,
///  subject: {kind: "di", entity},
///  findings: [{kind, file, member, fix}],
///  drifts, details: {danglingClasses[], deadImports[]}}
/// ```
///
/// Text mode (no `--json`) keeps the #974 verdict prose surface
/// byte-compatible with the previous `CapabilityCommand` path: pass
/// prints `✅ <verdict>`, findings print `❌ Failed: <verdict>` — the
/// verdict message carries the same `--> fix:` lines as before.
///
/// Exit codes (unchanged semantics): 0 = verified clean, 1 = findings.
/// Receipt persistence is intentionally not wired here: the gate is
/// read-only and generates no files, so per the #996 contract ("no
/// artifact, no receipt") there is nothing to receipt.
class DiVerifyCommand extends Command<void> {
  final DiPlugin plugin;

  /// Project root the gate resolves classes and package configs from.
  /// Injectable so tests can point at a temp fixture; null defers to the
  /// capability default (the current working directory — the CLI
  /// contract: `zfa` runs from the project it operates on).
  final String? projectRoot;

  DiVerifyCommand(this.plugin, {this.projectRoot}) {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a single zuraffa.verdict.v1 envelope on stdout '
          '(CI-able, issue #1108).',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify DI registrations resolve against classes on disk '
      '(dangling bindings fail with a fix hint).';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    // The gate verifies the whole di/ tree (unchanged #974 semantics);
    // the optional positional names the subject for the envelope.
    final entity = rest.isEmpty ? null : rest.first;
    final jsonMode = argResults?['json'] == true;

    final capability = DiVerifyCapability(plugin, projectRoot: projectRoot);
    final result = await capability.execute(const <String, dynamic>{});

    if (jsonMode) {
      // No prose: agents/CI consume stdout directly.
      print(jsonEncode(_envelope(result, entity)));
    } else {
      // Byte-compatible with the pre-#1108 CapabilityCommand prose for
      // this read-only capability (issue #1108 constraint: existing
      // --> fix: output is unchanged when --json is absent).
      if (result.success) {
        // ignore: avoid_print
        print('✅ ${result.message}');
      } else {
        // ignore: avoid_print
        print('❌ Failed: ${result.message}');
      }
    }
    exitCode = result.success ? 0 : 1;
  }

  /// The canonical #1104 `zuraffa.verdict.v1` envelope — no ad-hoc
  /// shapes. Built from the capability's structured findings; the verdict
  /// and exit codes derive from the same success flag the text path uses.
  Map<String, dynamic> _envelope(ExecutionResult result, String? entity) {
    final data = result.data ?? const <String, dynamic>{};
    final rawFindings =
        (data['findings'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final danglingClasses = <String>[];
    final deadImports = <String>[];
    final findings = rawFindings
        .map((f) {
          final kind = f['kind'] as String?;
          final member = f['member'];
          if (kind == 'dangling binding') {
            if (member is String && !danglingClasses.contains(member)) {
              danglingClasses.add(member);
            }
          } else if (kind == 'dangling import') {
            if (member is String && !deadImports.contains(member)) {
              deadImports.add(member);
            }
          }
          return <String, dynamic>{
            'kind': f['kind'],
            'file': f['file'],
            'member': member,
            'fix': _cleanFix(f['fix'] as String?),
          };
        })
        .toList(growable: false);

    return <String, dynamic>{
      'schema': DiVerifyEnvelope.schema,
      'command': 'di verify',
      'verdict': result.success ? 'pass' : 'fail',
      'exit_class': result.success ? 'ok' : 'fail',
      'subject': <String, dynamic>{'kind': 'di', 'entity': entity},
      'findings': findings,
      'drifts': const <String>[],
      'details': <String, dynamic>{
        'danglingClasses': danglingClasses,
        'deadImports': deadImports,
      },
    };
  }

  /// The text-mode `--> fix: ` marker is the line-oriented protocol
  /// prefix (#978 verdict protocol); the JSON `fix` value is the clean
  /// remediation text — a JSON consumer must not have to strip a marker.
  static String? _cleanFix(String? fix) =>
      fix?.replaceFirst(RegExp(r'^--> fix:\s*'), '');
}

/// The stable keys of the `zuraffa.verdict.v1` envelope (issue #1108).
/// Consumers grep for the schema name; drift is a treaty violation.
abstract final class DiVerifyEnvelope {
  /// The stable schema name.
  static const String schema = 'zuraffa.verdict.v1';
}
