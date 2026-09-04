/// VerifySliceCapability (spec 043; 073 adds the machine-readable JSON
/// verdict): slice integrity verification (US6, FR-013..FR-015).
///
/// Fast mode checks that every import in the sandbox resolves (ImportVerifier);
/// analyze mode additionally runs `dart analyze` through an injectable
/// process seam. `cut --verify` reuses this capability and rolls the
/// sandbox back when verification fails.
///
/// 073 `json` mode emits the three-check verdict (self-containment,
/// mock certification, suite state) to `.zuraffa/slices/<name>/verify-verdict.json`
/// and names every failing check with its offenders and a fix hint.
library;

import 'dart:convert';
import 'dart:io';

import '../../../core/plugin_system/capability.dart';
import '../capabilities/cut_slice_capability.dart';
import '../generators/manifest_writer.dart';
import '../models/slice_manifest.dart';
import '../verifier/analyze_runner.dart';
import '../verifier/import_verifier.dart';
import '../verifier/slice_verifier.dart';

/// Process execution seam for the analyzer (see [AnalyzeRunner]).
typedef AnalyzeLauncher =
    Future<ProcessResult> Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
    });

/// Verifies slice integrity.
class VerifySliceCapability implements ZuraffaCapability {
  /// Creates the capability with injectable collaborators.
  VerifySliceCapability({
    ImportVerifier? importVerifier,
    AnalyzeRunner? analyzeRunner,
    SliceVerifier? sliceVerifier,
    ManifestWriter? manifestWriter,
  }) : _importVerifier = importVerifier ?? ImportVerifier(),
       _analyzeRunner = analyzeRunner ?? AnalyzeRunner(),
       _sliceVerifier =
           sliceVerifier ?? SliceVerifier(suiteRunner: _processSuiteRunner),
       _manifestWriter = manifestWriter ?? ManifestWriter();

  /// The default sandbox suite runner: the sandbox's own `dart test`,
  /// run to completion in-process.
  static SuiteOutcome _processSuiteRunner(String sandboxDir) {
    final result = Process.runSync(
      'dart',
      ['test'],
      workingDirectory: sandboxDir,
      runInShell: true,
    );
    final passed = result.exitCode == 0;
    final failures = passed
        ? <String>[]
        : const LineSplitter()
              .convert(result.stdout.toString())
              .where((line) => line.contains('[E]'))
              .toList();
    return SuiteOutcome(passed: passed, failures: failures);
  }

  final ImportVerifier _importVerifier;
  final AnalyzeRunner _analyzeRunner;
  final SliceVerifier? _sliceVerifier;
  final ManifestWriter _manifestWriter;

  /// The verdict file `slice verify --json` writes and `slice merge`
  /// gates on.
  static String verdictPathFor(String sandboxDir) =>
      '$sandboxDir/verify-verdict.json';

  @override
  String get name => 'verify_slice';

  @override
  String get description =>
      'Check that every import in a slice resolves (and optionally run the '
      'analyzer); --json emits the three-check machine verdict.';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'projectRoot': {'type': 'string'},
      'analyze': {'type': 'boolean'},
      'json': {'type': 'boolean'},
      'hostRoot': {'type': 'string'},
      'runSuite': {'type': 'boolean'},
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'success': {'type': 'boolean'},
      'issues': {'type': 'array'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    final dartFiles = Directory(sandboxDir).existsSync()
        ? Directory(
            sandboxDir,
          ).listSync(recursive: true).whereType<File>().length
        : 0;
    return EffectReport(
      planId: 'verify-$sliceName',
      pluginId: 'slice',
      capabilityName: name,
      args: args,
      changes: [Effect(file: sandboxDir, action: 'check $dartFiles file(s)')],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final analyze = args['analyze'] as bool? ?? false;
    final launcher = args['analyzeLauncher'] as AnalyzeLauncher?;

    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    if (!Directory(sandboxDir).existsSync()) {
      return ExecutionResult(
        success: false,
        message:
            'No slice named "$sliceName" found at '
            '$sandboxDir --> fix: run `zfa slice cut $sliceName --entry '
            '<point>` first (issue #961 verify).',
      );
    }

    if (args['json'] as bool? ?? false) {
      return _executeVerdict(
        args,
        sandboxDir: sandboxDir,
        sliceName: sliceName,
      );
    }

    final report = _importVerifier.verify(
      sandboxDir: sandboxDir,
      projectRoot: projectRoot,
    );

    final data = <String, dynamic>{
      'filesChecked': report.filesChecked,
      'issues': [
        for (final issue in report.issues)
          {
            'file': issue.file,
            'line': issue.line,
            'importPath': issue.importPath,
            'reason': issue.reason,
          },
      ],
    };

    if (!report.passed) {
      return ExecutionResult(
        success: false,
        message:
            '${report.issues.length} unresolved import(s) in slice '
            '"$sliceName" — the slice is NOT ready for an agent.',
        data: data,
      );
    }

    if (analyze) {
      final runner = launcher != null
          ? AnalyzeRunner(launcher: launcher)
          : _analyzeRunner;
      final analyzeResult = await runner.analyze(sandboxDir);
      data['analyzeErrors'] = analyzeResult.errors;
      if (analyzeResult.toolchainMissing) {
        return ExecutionResult(
          success: false,
          message: analyzeResult.message,
          data: data,
        );
      }
      if (!analyzeResult.passed) {
        return ExecutionResult(
          success: false,
          message:
              'dart analyze reported ${analyzeResult.errors.length} error(s) '
              'in slice "$sliceName".',
          data: data,
        );
      }
      data['analyzeClean'] = true;
    }

    return ExecutionResult(
      success: true,
      message:
          'Slice "$sliceName" verified: all imports resolved across '
          '${report.filesChecked} file(s)'
          '${analyze ? ' and the analyzer is clean' : ''} — ready for use.',
      data: data,
    );
  }

  /// The 073 verdict path: three named checks, machine-readable JSON,
  /// failing checks named with offenders and fix hints.
  Future<ExecutionResult> _executeVerdict(
    Map<String, dynamic> args, {
    required String sandboxDir,
    required String sliceName,
  }) async {
    final hostRoot = args['hostRoot'] as String?;
    final runSuite = args['runSuite'] as bool? ?? true;

    final SliceManifest manifest;
    try {
      manifest = await _manifestWriter.read(sandboxDir);
    } on SliceManifestError catch (e) {
      return ExecutionResult(
        success: false,
        message:
            '${e.message} --> fix: re-run `zfa slice cut $sliceName` to '
            'regenerate the manifest (issue #961 verify).',
      );
    }

    final verifier =
        _sliceVerifier ?? SliceVerifier(suiteRunner: _processSuiteRunner);
    final verdict = verifier.verify(
      sandboxDir: sandboxDir,
      manifest: manifest,
      hostRoot: hostRoot,
      runSuite: runSuite,
    );

    final verdictFile = File(verdictPathFor(sandboxDir));
    await verdictFile.parent.create(recursive: true);
    await verdictFile.writeAsString(verdict.encode());

    final buffer = StringBuffer(verdict.summaryLine(sliceName));
    if (!verdict.passed) {
      for (final failure in verdict.failures) {
        buffer.write('\n  FAILED check "${failure.name}":');
        for (final offender in failure.offenders) {
          buffer.write('\n    - $offender');
        }
      }
      buffer.write(
        '\n--> fix: resolve every named offender, then re-run '
        '`zfa slice verify --json $sliceName` (issue #961).',
      );
    }

    return ExecutionResult(
      success: verdict.passed,
      message: buffer.toString(),
      data: {
        'verdict': verdict.toJson(),
        'verdictPath': verdictFile.path,
        'passed': verdict.passed,
      },
    );
  }
}
