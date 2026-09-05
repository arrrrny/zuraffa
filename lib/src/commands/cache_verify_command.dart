import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/cache/cache_plugin.dart';
import '../plugins/cache/cache_verify.dart';

/// `zfa cache verify <Entity> [--json]` — the cache drift gate
/// (spec #975, Order 3).
///
/// Reads the registrar + the entity graph; lists entities whose adapters
/// are missing or stale; exits 1 with one `--> fix:` line per finding so
/// cache drift becomes a CI gate. `--json` emits a single parseable
/// `cache.verify.v1` verdict object (mirrors `zfa proof check --format
/// json`, issue #778).
///
/// Registered manually on [CacheCommand] (the `manualSubcommandNames`
/// hook, issue #761) rather than auto-derived from a capability: the
/// generic `CapabilityCommand` already owns `--json` as *JSON input*, and
/// for this command `--json` must select *JSON output*.
class CacheVerifyCommand extends Command<void> {
  final CachePlugin plugin;

  CacheVerifyCommand(this.plugin) {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a single cache.verify.v1 verdict object on stdout '
          '(CI-able).',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify Hive adapter coverage for an entity against the entity '
      'graph; exit 1 on drift (spec #975).';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print('❌ Usage: $invocation <Entity> [--json]');
      print('   Verify the registrar covers every discovered entity.');
      print(
        '   Run `zfa cache adapter <Entity>` to (re-)register the '
        'adapters first.',
      );
      exitCode = 64;
      return;
    }
    final entityName = rest.first;
    final jsonMode = argResults?['json'] == true;

    final verifier = CacheAdapterVerifier(
      outputDir: plugin.outputDir,
      projectRoot: Directory.current.path,
      fileSystem: plugin.cacheBuilder.fileSystem,
    );

    final CacheVerifyReport report;
    try {
      report = await verifier.verify(entityName);
    } on CacheEntityNotFoundException catch (e) {
      print('❌ $e');
      exitCode = 1;
      return;
    }

    if (jsonMode) {
      // No prose: agents/CI consume stdout directly.
      print(jsonEncode(report.toJson()));
    } else {
      _printText(report);
    }
    exitCode = report.ok ? 0 : 1;
  }

  void _printText(CacheVerifyReport report) {
    print('Cache Verify (registrar + entity graph — spec #975)');
    print('====================================================');
    print(
      'Entity: ${report.entity} — expected ${report.expectedEntities.length} '
      'adapter(s), registered ${report.registeredEntities.length}.',
    );

    if (report.findings.isEmpty) {
      print(
        '✓ cache verified: every discovered entity has an adapter '
        '(${report.expectedEntities.join(', ')}).',
      );
      return;
    }

    print('');
    print('Findings (${report.findings.length}):');
    for (final finding in report.findings) {
      print('  [${finding.kind}] ${finding.entity}');
      print('    ${finding.detail}');
      print('    --> fix: ${finding.fix}');
    }
    print('');
    print('cache verify: ${report.findings.length} finding(s) — FAIL');
  }
}
