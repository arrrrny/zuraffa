/// MergeSliceCapability (spec 043; 073 adds the verify gate, the
/// receipts landing, and the host-suite report).
///
/// Plan: preview which files would be copied, conflicted, or deleted.
/// Execute: gate on the slice's verify verdict (refusing when it is
/// failing or absent, naming the failed check), run the merger, land
/// the feature's artifacts + journal + registry into the host, then run
/// the HOST suite and report its outcome.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/context/progress_reporter.dart';
import '../../../core/plugin_system/capability.dart';
import '../capabilities/cut_slice_capability.dart';
import '../capabilities/verify_slice_capability.dart';
import '../generators/manifest_writer.dart';
import '../merger/conflict_detector.dart';
import '../merger/slice_merger.dart';
import '../models/slice_file.dart';
import '../models/slice_manifest.dart';
import '../models/slice_verdict.dart';

/// Outcome of one host suite run (injectable seam).
class HostSuiteOutcome {
  final bool passed;
  final List<String> failures;

  const HostSuiteOutcome({required this.passed, this.failures = const []});
}

/// Runs the host suite; injectable so merge stays hermetic in tests.
typedef HostSuiteRunner =
    Future<HostSuiteOutcome> Function(String projectRoot);

/// Merge agent changes from a slice back into the main project.
class MergeSliceCapability implements ZuraffaCapability {
  /// Creates the capability with injectable collaborators.
  MergeSliceCapability({
    ManifestWriter? manifestWriter,
    SliceMerger? merger,
    HostSuiteRunner? hostSuiteRunner,
  }) : _manifestWriter = manifestWriter ?? ManifestWriter(),
       _merger = merger ?? SliceMerger(),
       _hostSuiteRunner = hostSuiteRunner;

  final ManifestWriter _manifestWriter;
  final SliceMerger _merger;
  final HostSuiteRunner? _hostSuiteRunner;

  @override
  String get name => 'merge_slice';

  @override
  String get description =>
      'Merge agent modifications from a slice sandbox back into the project '
      '(gated on a passing slice verify).';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'projectRoot': {'type': 'string'},
      'confirmAll': {'type': 'boolean'},
      'feature': {'type': 'string'},
      'runHostSuite': {'type': 'boolean'},
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'success': {'type': 'boolean'},
      'copied': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'conflicts': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);

    try {
      final manifest = await _manifestWriter.read(sandboxDir);
      final detector = ConflictDetector();
      final changes = <Effect>[];
      for (final file in manifest.files) {
        final sandboxHash = _hashIfExists(
          p.join(sandboxDir, file.relativePath),
        );
        final mainHash = _hashIfExists(p.join(projectRoot, file.relativePath));
        final decision = detector.decide(
          cutHash: file.hashAtCut,
          sandboxHash: sandboxHash,
          mainHash: mainHash,
        );
        changes.add(
          Effect(
            file: file.relativePath,
            action: switch (decision) {
              MergeDecision.skip => 'skip',
              MergeDecision.safeCopy =>
                file.ownership == FileOwnership.shared
                    ? 'copy (shared — needs confirmation)'
                    : 'copy',
              MergeDecision.conflict => 'conflict',
              MergeDecision.sandboxDeleted => 'delete',
              MergeDecision.agentCreated => 'create',
            },
          ),
        );
      }
      return EffectReport(
        planId: 'merge-$sliceName',
        pluginId: 'slice',
        capabilityName: name,
        args: args,
        changes: changes,
      );
    } catch (e) {
      return EffectReport(
        planId: 'merge-$sliceName',
        pluginId: 'slice',
        capabilityName: name,
        args: args,
        isValid: false,
        message: e.toString(),
        changes: const [],
      );
    }
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final confirmAll = args['confirmAll'] as bool? ?? false;
    final feature = args['feature'] as String?;
    final runHostSuite = args['runHostSuite'] as bool? ?? true;
    final confirmOverwrite =
        args['confirmSharedOverwrite'] as bool Function(SliceFile)? ??
        (_) => confirmAll;
    final confirmDelete =
        args['confirmSharedDelete'] as bool Function(String)? ??
        (_) => confirmAll;
    final progress =
        args['progressReporter'] as ProgressReporter? ?? NullProgressReporter();

    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    if (!Directory(sandboxDir).existsSync()) {
      return ExecutionResult(
        success: false,
        message:
            'No slice named "$sliceName" found at '
            '${p.relative(sandboxDir, from: projectRoot)} --> fix: run '
            '`zfa slice cut $sliceName --entry <point>` first (issue #961 '
            'merge).',
      );
    }

    // 073 gate: merge requires a verified slice — the verdict must
    // exist and pass, and the refusal names the failed check.
    final gate = gateOnVerdict(sandboxDir, sliceName: sliceName);
    if (gate != null) {
      return gate;
    }

    final SliceManifest manifest;
    try {
      manifest = await _manifestWriter.read(sandboxDir);
    } on SliceManifestError catch (e) {
      return ExecutionResult(success: false, message: e.message);
    }

    progress.update('comparing ${manifest.files.length} manifest file(s)');
    final report = await _merger.merge(
      manifest: manifest,
      sandboxDir: sandboxDir,
      projectRoot: projectRoot,
      confirmSharedOverwrite: confirmOverwrite,
      confirmSharedDelete: confirmDelete,
    );
    progress.update('resolving merge decisions');

    final landed = feature == null || feature.isEmpty
        ? const <String>[]
        : landReceipts(
            sandboxDir: sandboxDir,
            projectRoot: projectRoot,
            feature: feature,
          );

    var suitePassed = true;
    var suiteFailures = const <String>[];
    if (runHostSuite) {
      progress.update('running the host suite');
      final runner = _hostSuiteRunner ?? _defaultHostSuiteRunner;
      final outcome = await runner(projectRoot);
      suitePassed = outcome.passed;
      suiteFailures = outcome.failures;
    }

    final reportLine = hostSuiteReport(
      mergeClean: report.noChanges || report.clean,
      outcome: runHostSuite
          ? HostSuiteOutcome(passed: suitePassed, failures: suiteFailures)
          : null,
    );
    final message = StringBuffer(report.message ?? '');
    if (landed.isNotEmpty) {
      message.write(' Landed ${landed.length} receipt file(s) for '
          '"$feature" into the host.');
    }
    message.write(reportLine.report);

    return ExecutionResult(
      success: reportLine.success,
      files: [...report.copied, ...report.created, ...landed],
      message: message.toString(),
      data: {
        'copied': report.copied,
        'created': report.created,
        'deleted': report.deleted,
        'conflicts': report.conflicts,
        'unconfirmedShared': report.unconfirmedShared,
        'warnings': report.warnings,
        'skipped': report.skipped,
        'landedReceipts': landed,
        'hostSuitePassed': suitePassed,
        'hostSuiteFailures': suiteFailures,
      },
    );
  }

  /// The host-suite report and success verdict (sync core): merge
  /// succeeds only when the merger was clean AND the host suite ran
  /// green; the report names failures with a fix hint on red.
  static ({bool success, String report}) hostSuiteReport({
    required bool mergeClean,
    required HostSuiteOutcome? outcome,
  }) {
    if (outcome == null) {
      return (success: mergeClean, report: '');
    }
    if (outcome.passed) {
      return (success: mergeClean, report: ' Host suite: green.');
    }
    return (
      success: false,
      report:
          ' Host suite: FAILED (${outcome.failures.length}) — '
          '${outcome.failures.take(3).join("; ")}'
          '${outcome.failures.length > 3 ? "…" : ""} --> fix: make the '
          'host suite green after landing (issue #961).',
    );
  }

  /// Non-null refusal when the verdict is absent or failing; null when
  /// the merge may proceed. Sync so the gate is directly exercisable.
  static ExecutionResult? gateOnVerdict(String sandboxDir,
      {required String sliceName}) {
    final verdictFile = File(VerifySliceCapability.verdictPathFor(sandboxDir));
    if (!verdictFile.existsSync()) {
      return ExecutionResult(
        success: false,
        message:
            'Merge refused: slice "$sliceName" has no verify verdict '
            '(missing ${p.relative(verdictFile.path)}) -- merge requires a '
            'verified slice --> fix: run `zfa slice verify --json '
            '$sliceName` first (issue #961).',
      );
    }
    final verdict = SliceVerdict.decode(verdictFile.readAsStringSync());
    if (!verdict.passed) {
      final buffer = StringBuffer(
        'Merge refused: slice "$sliceName" failed slice verify -- '
        'merge requires a verified slice.',
      );
      for (final failure in verdict.failures) {
        buffer.write('\n  FAILED check "${failure.name}":');
        for (final offender in failure.offenders) {
          buffer.write('\n    - $offender');
        }
      }
      buffer.write(
        '\n--> fix: resolve every named offender, re-run '
        '`zfa slice verify --json $sliceName`, then merge (issue #961).',
      );
      return ExecutionResult(success: false, message: buffer.toString());
    }
    return null;
  }

  /// Copy the feature's receipts (spec + tdd journal + artifact
  /// registry) from the sandbox into the host; returns the landed
  /// relative paths. Sync so the landing is directly exercisable.
  static List<String> landReceipts({
    required String sandboxDir,
    required String projectRoot,
    required String feature,
  }) {
    final source = Directory(p.join(sandboxDir, 'specs', feature));
    if (!source.existsSync()) return const [];
    final landed = <String>[];
    for (final entity in source.listSync(recursive: true)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: sandboxDir);
      final target = p.join(projectRoot, rel);
      final targetFile = File(target);
      targetFile.parent.createSync(recursive: true);
      entity.copySync(target);
      landed.add(rel);
    }
    return landed..sort();
  }

  static Future<HostSuiteOutcome> _defaultHostSuiteRunner(
    String projectRoot,
  ) async {
    final result = await Process.run(
      'dart',
      ['test'],
      workingDirectory: projectRoot,
      runInShell: true,
    );
    final passed = result.exitCode == 0;
    final failures = passed
        ? <String>[]
        : const LineSplitter()
              .convert(result.stdout.toString())
              .where((line) => line.contains('[E]'))
              .toList();
    return HostSuiteOutcome(passed: passed, failures: failures);
  }

  String? _hashIfExists(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    return sha256.convert(file.readAsBytesSync()).toString();
  }
}
