/// Named environment checks for `zfa doctor` (issue #793).
///
/// `DoctorCommand` historically reported tooling versions and v5 migration
/// readiness, but every environment failure mode the command-matrix
/// healthcheck hit required a human who already knew the remedy. This module
/// turns those failure modes into named, fixable checks:
///
/// - `deps`           — TDD dev-deps present (mocktail/coverage/mutation_test)
///                      + zuraffa pin vs CLI version (warn-only)
/// - `artifacts`      — build_runner partial outputs (entity source without
///                      sibling `.g.dart`/`.zorphy.dart`)
/// - `baseline-cache` — `specs/*/tdd/run-baseline.json` readable, schema-valid,
///                      fresh (mirrors `RunBaselineCache`'s fail-safe nulls but
///                      reports WHY instead of silently falling back)
/// - `config`         — `.zfa.json` parses + plugin keys are known
/// - `profile`        — TDD project has `.specify/memory/tdd-profile.md`
///
/// Fixes are mechanical and idempotent: `dart pub add` for missing dev-deps,
/// build_runner for stale artifacts, deletion for corrupt/stale baseline
/// caches, in-process `tdd init` for a missing profile. Process spawning is
/// injectable via [ZfaProcessRunner] so tests stay hermetic.
///
/// Exit contract (issue #793 AC): exit 0 iff every executed check is ok
/// (pass/fixed/warn/skipped), otherwise 1 — evaluated after the fix pass.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config/zfa_config.dart';
import '../plugins/tdd/tdd_plugin.dart';
import '../version.dart';
import 'tdd_command.dart';

/// Status of a single named doctor check.
enum DoctorCheckStatus { pass, fail, fixed, warn, skipped }

/// The verdict of one named doctor check.
class DoctorCheckResult {
  const DoctorCheckResult({
    required this.id,
    required this.status,
    required this.detail,
    this.suggestedFix,
    this.fixedItems = const [],
  });

  final String id;
  final DoctorCheckStatus status;
  final String detail;

  /// The exact command that heals this failure, when one exists.
  final String? suggestedFix;

  /// Items (files installed/deleted, profile paths) changed by `--fix`.
  final List<String> fixedItems;

  /// A failed check is the only non-ok outcome: `warn` degrades honestly
  /// without failing CI, `skipped` means not applicable.
  bool get ok => status != DoctorCheckStatus.fail;

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'detail': detail,
    if (suggestedFix != null) 'suggested_fix': suggestedFix,
    'fixed_items': fixedItems,
  };

  @override
  String toString() => 'DoctorCheckResult(${toJson()})';
}

/// Signature for the process spawner used by the mechanical fixes.
/// Injectable so tests can record invocations without side effects.
typedef ZfaProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> args);

/// Runs the five named environment checks against a project root.
class DoctorChecksRunner {
  DoctorChecksRunner({ZfaProcessRunner? processRunner, String? projectDir})
    : _processRunner = processRunner ?? _defaultProcessRunner,
      _projectDir = projectDir;

  final ZfaProcessRunner _processRunner;
  final String? _projectDir;

  /// Dev-deps the TDD loop needs after a fresh clone (issue #793).
  static const requiredDevDeps = {'mocktail', 'coverage', 'mutation_test'};

  /// Fallback spawner with a generous timeout for build_runner.
  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> args,
  ) async {
    return Process.run(executable, args).timeout(const Duration(minutes: 10));
  }

  String get _root => _projectDir ?? Directory.current.path;

  /// Execute all named checks in report order. When [fix] is true, mechanical
  /// failures are healed in place; the returned verdicts reflect the state
  /// AFTER healing (fixed or honestly still failing).
  Future<List<DoctorCheckResult>> runAll({required bool fix}) async => [
    await _checkDeps(fix: fix),
    await _checkArtifacts(fix: fix),
    await _checkBaselineCache(fix: fix),
    await _checkConfig(fix: fix),
    await _checkProfile(fix: fix),
  ];

  DoctorCheckResult _pass(String id, String detail) =>
      DoctorCheckResult(id: id, status: DoctorCheckStatus.pass, detail: detail);

  DoctorCheckResult _fail(String id, String detail, String? suggestedFix) =>
      DoctorCheckResult(
        id: id,
        status: DoctorCheckStatus.fail,
        detail: detail,
        suggestedFix: suggestedFix,
      );

  // ---------------------------------------------------------------------------
  // deps
  // ---------------------------------------------------------------------------

  Future<DoctorCheckResult> _checkDeps({required bool fix}) async {
    const id = 'deps';
    final pubspecFile = File(p.join(_root, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return DoctorCheckResult(
        id: id,
        status: DoctorCheckStatus.skipped,
        detail: 'no pubspec.yaml (not a Dart project)',
      );
    }

    YamlMap doc;
    try {
      doc = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    } catch (e) {
      return _fail(
        id,
        'pubspec.yaml unreadable: $e',
        'fix pubspec.yaml syntax',
      );
    }
    final devDeps = (doc['dev_dependencies'] as YamlMap?) ?? YamlMap();
    final present = devDeps.keys.map((k) => k.toString()).toSet();
    final missing = requiredDevDeps.difference(present).toList()..sort();

    // zuraffa pin vs CLI version — warn-only per FR-2.
    String? pinWarn;
    final pin = (doc['dependencies'] as YamlMap?)?['zuraffa'];
    if (pin is String) {
      final pinnedMajor = int.tryParse(
        RegExp(r'\d+').firstMatch(pin)?.group(0) ?? '',
      );
      final cliMajor = int.tryParse(version.split('.').first);
      if (pinnedMajor != null && cliMajor != null && pinnedMajor < cliMajor) {
        pinWarn = 'zuraffa pin $pin is behind CLI v$version';
      }
    }

    final isTddProject =
        Directory(p.join(_root, 'specs')).existsSync() ||
        Directory(p.join(_root, '.specify')).existsSync();

    if (!isTddProject && missing.isEmpty) {
      return pinWarn == null
          ? DoctorCheckResult(
              id: id,
              status: DoctorCheckStatus.skipped,
              detail: 'not a TDD project — dev-deps check not applicable',
            )
          : DoctorCheckResult(
              id: id,
              status: DoctorCheckStatus.warn,
              detail: pinWarn,
            );
    }

    if (missing.isEmpty) {
      return pinWarn == null
          ? _pass(id, 'TDD dev-deps present')
          : DoctorCheckResult(
              id: id,
              status: DoctorCheckStatus.warn,
              detail: pinWarn,
            );
    }

    final detail =
        'missing dev-deps: ${missing.join(', ')}'
        '${pinWarn == null ? '' : '; $pinWarn'}';
    final suggested = 'dart pub add ${missing.map((d) => 'dev:$d').join(' ')}';

    if (fix) {
      final result = await _processRunner('dart', [
        'pub',
        'add',
        ...missing.map((d) => 'dev:$d'),
      ]);
      if (result.exitCode == 0) {
        return DoctorCheckResult(
          id: id,
          status: DoctorCheckStatus.fixed,
          detail: 'installed ${missing.join(', ')}',
          suggestedFix: suggested,
          fixedItems: missing,
        );
      }
      return _fail(
        id,
        '$detail (pub add failed with exit ${result.exitCode})',
        suggested,
      );
    }
    return _fail(id, detail, suggested);
  }

  // ---------------------------------------------------------------------------
  // artifacts
  // ---------------------------------------------------------------------------

  Future<DoctorCheckResult> _checkArtifacts({required bool fix}) async {
    const id = 'artifacts';
    final entitiesDir = Directory(p.join(_root, 'lib/src/domain/entities'));
    if (!entitiesDir.existsSync()) return _pass(id, 'no entities directory');

    String? findings;
    for (final entity in _entitySources(entitiesDir)) {
      final missing = <String>[];
      final stem = entity.path.substring(
        0,
        entity.path.length - '.dart'.length,
      );
      if (!File('$stem.g.dart').existsSync()) missing.add('.g.dart');
      if (!File('$stem.zorphy.dart').existsSync()) missing.add('.zorphy.dart');
      if (missing.isEmpty) continue;
      final rel = p.relative(entity.path, from: _root);
      findings = findings == null
          ? '$rel missing ${missing.join(' and ')}'
          : '$findings; $rel missing ${missing.join(' and ')}';
    }

    if (findings == null) return _pass(id, 'all entity artifacts present');
    const suggested =
        'dart run build_runner build --delete-conflicting-outputs';

    if (fix) {
      final result = await _processRunner('dart', [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ]);
      final stillMissing = _entitySources(entitiesDir).any((entity) {
        final stem = entity.path.substring(
          0,
          entity.path.length - '.dart'.length,
        );
        return !File('$stem.g.dart').existsSync() ||
            !File('$stem.zorphy.dart').existsSync();
      });
      if (result.exitCode == 0 && !stillMissing) {
        return DoctorCheckResult(
          id: id,
          status: DoctorCheckStatus.fixed,
          detail: 'regenerated entity artifacts',
          suggestedFix: suggested,
          fixedItems: [suggested],
        );
      }
      return _fail(
        id,
        '$findings (build_runner exited ${result.exitCode})',
        suggested,
      );
    }
    return _fail(id, findings, suggested);
  }

  List<File> _entitySources(Directory entitiesDir) {
    final generatedSuffixes = ['.g.dart', '.zorphy.dart', '.freezed.dart'];
    return entitiesDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => !generatedSuffixes.any((s) => p.basename(f.path).endsWith(s)),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  // ---------------------------------------------------------------------------
  // baseline-cache
  // ---------------------------------------------------------------------------

  Future<DoctorCheckResult> _checkBaselineCache({required bool fix}) async {
    const id = 'baseline-cache';
    final specsDir = Directory(p.join(_root, 'specs'));
    if (!specsDir.existsSync()) {
      return _pass(id, 'no cached baselines present');
    }

    final problems = <String>[];
    final victims = <String>[];
    for (final featureDir
        in specsDir.listSync(followLinks: false).whereType<Directory>()) {
      final cacheFile = File(
        p.join(featureDir.path, 'tdd', 'run-baseline.json'),
      );
      if (!cacheFile.existsSync()) continue;
      final why = _diagnoseBaselineCache(cacheFile);
      if (why != null) {
        problems.add('${p.relative(cacheFile.path, from: _root)}: $why');
        victims.add(cacheFile.path);
      }
    }

    if (problems.isEmpty) {
      return _pass(
        id,
        victims.isEmpty
            ? 'no cached baselines present'
            : 'baseline caches readable and fresh',
      );
    }

    final detail = problems.join('; ');
    final suggested = victims.map((v) => 'rm $v').join(' && ');

    if (fix) {
      for (final victim in victims) {
        try {
          File(victim).deleteSync();
        } catch (e) {
          return _fail(id, '$detail (could not delete cache: $e)', suggested);
        }
      }
      return DoctorCheckResult(
        id: id,
        status: DoctorCheckStatus.fixed,
        detail:
            'invalidated ${victims.length} corrupt/stale baseline cache(s) '
            '(next tdd run re-captures live)',
        suggestedFix: suggested,
        fixedItems: victims,
      );
    }
    return _fail(id, detail, suggested);
  }

  /// Mirrors `RunBaselineCache.read`'s fail-safe null but reports WHY the
  /// cache would be rejected (issue #793: "expose WHY it returned null").
  /// Returns null when the cache is usable and fresh.
  String? _diagnoseBaselineCache(File cacheFile) {
    String raw;
    try {
      raw = cacheFile.readAsStringSync();
    } catch (e) {
      return 'unreadable: $e';
    }
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return 'invalid JSON';
    }
    if (json is! Map) return 'not a JSON object';
    if (json['command'] is! String) return 'missing/invalid field: command';
    if (json['exitCode'] is! int) return 'missing/invalid field: exitCode';
    if (json['failedTests'] is! List) {
      return 'missing/invalid field: failedTests';
    }
    final capturedAt = json['capturedAt'];
    if (capturedAt is! String) return 'missing/invalid field: capturedAt';
    if (json['parseable'] is! bool) return 'missing/invalid field: parseable';

    DateTime captured;
    try {
      captured = DateTime.parse(capturedAt);
    } catch (_) {
      return 'unparseable capturedAt: $capturedAt';
    }

    final testDir = Directory(p.join(_root, 'test'));
    if (testDir.existsSync()) {
      DateTime? newest;
      for (final entity in testDir.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final modified = entity.lastModifiedSync();
        if (newest == null || modified.isAfter(newest)) newest = modified;
      }
      if (newest != null && newest.isAfter(captured)) {
        return 'stale (test/ changed at ${newest.toIso8601String()} after '
            'capture at $capturedAt)';
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // config
  // ---------------------------------------------------------------------------

  Future<DoctorCheckResult> _checkConfig({required bool fix}) async {
    const id = 'config';
    final configFile = File(p.join(_root, '.zfa.json'));
    if (!configFile.existsSync()) return _pass(id, 'no .zfa.json (optional)');

    Object? json;
    try {
      json = jsonDecode(configFile.readAsStringSync());
    } catch (_) {
      return _fail(id, 'malformed JSON in .zfa.json', 'zfa config init');
    }
    if (json is! Map) {
      return _fail(
        id,
        '.zfa.json must contain a JSON object',
        'zfa config init',
      );
    }

    final plugins = json['plugins'];
    if (plugins is Map) {
      final unknown =
          plugins.keys
              .map((k) => k.toString())
              .where(
                (k) =>
                    k != 'defaults' && !ZfaConfig.builtinPluginIds.contains(k),
              )
              .toList()
            ..sort();
      if (unknown.isNotEmpty) {
        return DoctorCheckResult(
          id: id,
          status: DoctorCheckStatus.warn,
          detail: 'unknown plugin registration(s): ${unknown.join(', ')}',
        );
      }
    }
    return _pass(id, '.zfa.json valid');
  }

  // ---------------------------------------------------------------------------
  // profile
  // ---------------------------------------------------------------------------

  Future<DoctorCheckResult> _checkProfile({required bool fix}) async {
    const id = 'profile';
    if (!Directory(p.join(_root, 'specs')).existsSync()) {
      return _pass(id, 'not a TDD project');
    }
    final profileFile = File(
      p.join(_root, '.specify', 'memory', 'tdd-profile.md'),
    );
    if (profileFile.existsSync()) return _pass(id, 'tdd profile present');

    const suggested = 'zfa tdd init';
    if (fix) {
      try {
        final healer = CommandRunner<void>('zfa', 'doctor profile heal')
          ..addCommand(TddCommand(TddPlugin()));
        await healer.run(['tdd', 'init', '--project', _root]);
      } catch (e) {
        return _fail(
          id,
          'missing .specify/memory/tdd-profile.md (tdd init failed: $e)',
          suggested,
        );
      }
      if (profileFile.existsSync()) {
        return DoctorCheckResult(
          id: id,
          status: DoctorCheckStatus.fixed,
          detail: 'regenerated .specify/memory/tdd-profile.md via tdd init',
          suggestedFix: suggested,
          fixedItems: ['.specify/memory/tdd-profile.md'],
        );
      }
      return _fail(
        id,
        'missing .specify/memory/tdd-profile.md '
        '(tdd init did not create it)',
        suggested,
      );
    }
    return _fail(id, 'missing .specify/memory/tdd-profile.md', suggested);
  }
}

/// The `--format json` verdict object for the named environment checks:
/// `{"schema":"doctor.v1","checks":[...],"ok":<bool>}` (issue #793, per #778).
Map<String, dynamic> doctorChecksJson(List<DoctorCheckResult> results) => {
  'schema': 'doctor.v1',
  'checks': results.map((r) => r.toJson()).toList(),
  'ok': results.every((r) => r.ok),
};
