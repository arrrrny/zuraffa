/// `zfa tdd reset <feature>` — first-class recovery: revert a feature's
/// TDD state to clean (bug #840).
///
/// The command:
///   1. Resolves the feature directory (`specs/<feature>`) and loads the
///      artifact registry BEFORE touching anything.
///   2. Prints the diff summary — every registry record it will drop and
///      every owned file it will delete — BEFORE acting.
///   3. Deletes ONLY the files the registry records own (the recorded
///      `test_path`/`subject_path` of the feature's behaviors). Files on
///      disk that no record owns are FOREIGN: they are counted, reported
///      as kept, and never deleted.
///   4. Drops the registry (`tdd/artifacts.json`) and the feature's
///      run-state (`tdd/run-state.json`) — the two mutable stores a
///      restart needs clean. The cycle-log is append-only evidence and is
///      never touched; the audit log is history and is never touched.
///   5. Emits the machine-readable JSON verdict as the final stdout line
///      and exits 0 on success, 1 on refusal (unknown feature).
///
/// Ownership rule (hard constraint): reset NEVER deletes foreign files —
/// the delete set is exactly the union of the registry records' paths,
/// intersected with what actually exists on disk.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/artifact_registry.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class ResetCommand extends Command<void> {
  ResetCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/, test/, and lib/. When omitted, '
          'the current working directory is used.',
    );
  }

  bool _jsonMode = false;

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit (the
  /// legacy raw-JSON verdict line folds into it — ONE machine line).
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'reset';

  @override
  String get description =>
      'Revert a feature\'s TDD state to clean: drop the artifact registry '
      'entries and the generated tests/subjects the registry owns, reset '
      'run-state, and NEVER touch foreign files (bug #840). Prints the '
      'diff summary before acting.';

  @override
  String get invocation => 'zfa tdd reset <feature> [--project <path>]';

  @override
  Future<void> run() =>
      runWithVerdictEnvelope(this, _verdict, _run, featureFromRest: true);

  Future<void> _run() async {
    final rest = argResults?.rest ?? const <String>[];
    _jsonMode = argResults?['json'] as bool? ?? false;
    if (rest.isEmpty) {
      usageException(
        'Feature name is required: zfa tdd reset <feature> '
        '(e.g. 049-tdd-run)',
      );
    }
    final feature = rest.first;
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final featureDir = p.join(cwd, 'specs', feature);

    if (!await Directory(featureDir).exists()) {
      print('zfa tdd reset: no feature directory at specs/$feature');
      _printVerdict(
        feature: feature,
        verdict: 'refused',
        reason: 'no feature directory at specs/$feature',
      );
      _verdict.fix = 'create the feature (zfa tdd init / a spec) or check '
          'the feature name';
      exitCode = 1;
      return;
    }

    final registry = ArtifactRegistry(featureDir: featureDir);
    final records = await registry.loadAll();

    // The delete set: exactly the files the registry records OWN that
    // exist on disk. Everything else on disk is foreign and survives.
    final ownedExisting = <String>[];
    for (final record in records) {
      for (final path in [record.testPath, record.subjectPath]) {
        if (File(path).existsSync() && !ownedExisting.contains(path)) {
          ownedExisting.add(path);
        }
      }
    }
    final foreignKept = _countForeignGeneratedFiles(cwd, ownedExisting);

    // Diff summary BEFORE acting (bug #840).
    print('zfa tdd reset: feature $feature (specs/$feature/tdd)');
    print('  will drop ${records.length} registry record(s):');
    for (final record in records) {
      print('    - ${record.behaviorId} (${record.testPath})');
    }
    print('  will delete ${ownedExisting.length} owned file(s):');
    for (final path in ownedExisting) {
      print('    - ${p.relative(path, from: cwd)}');
    }
    print('  will reset tdd/run-state.json');
    print(
      '  will keep $foreignKept foreign generated file(s) untouched '
      '(never deleted)',
    );

    // Act: owned files first, then the registry, then run-state.
    for (final path in ownedExisting) {
      await File(path).delete();
    }
    final registryFile = File(registry.registryPath);
    if (await registryFile.exists()) await registryFile.delete();
    final runStateFile = File(p.join(featureDir, 'tdd', 'run-state.json'));
    if (await runStateFile.exists()) await runStateFile.delete();

    print('zfa tdd reset: feature=$feature dropped=${records.length}');
    _printVerdict(
      feature: feature,
      verdict: 'reset',
      droppedFiles: ownedExisting
          .map((path_) => p.relative(path_, from: cwd))
          .toList(),
      droppedRecords: records.length,
      foreignKept: foreignKept,
    );
    exitCode = 0;
  }

  /// Count generated-layout files on disk that are NOT in the owned delete
  /// set — the foreign files reset keeps (reported, never touched).
  int _countForeignGeneratedFiles(String cwd, List<String> owned) {
    var foreign = 0;
    for (final dir in [p.join(cwd, 'test', 'tdd'), p.join(cwd, 'lib', 'tdd')]) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final entity in d.listSync().whereType<File>()) {
        if (!owned.contains(entity.path)) foreign++;
      }
    }
    return foreign;
  }

  /// The machine-readable verdict (bug #840) — text when --json is
  /// absent; the envelope details when it is set (issue #969: ONE
  /// versioned machine line, never a second raw object).
  void _printVerdict({
    required String feature,
    required String verdict,
    String? reason,
    List<String> droppedFiles = const [],
    int droppedRecords = 0,
    int foreignKept = 0,
  }) {
    if (!_jsonMode) {
      print(
        'reset: feature=$feature verdict=$verdict'
        '${reason != null ? ' reason="$reason"' : ''}'
        ' dropped_records=$droppedRecords'
        ' foreign_files_kept=$foreignKept',
      );
      return;
    }
    _verdict
      ..feature = feature
      ..outcome = verdict == 'refused' ? VerdictOutcome.fail : VerdictOutcome.pass
      ..exitClass = verdict == 'refused' ? 'refused' : 'ok';
    _verdict.details
      ..['verdict'] = verdict
      ..['dropped_records'] = droppedRecords
      ..['foreign_files_kept'] = foreignKept;
    if (reason != null) _verdict.details['reason'] = reason;
    if (droppedFiles.isNotEmpty) {
      _verdict.details['dropped_files'] = droppedFiles;
    }
  }
}
