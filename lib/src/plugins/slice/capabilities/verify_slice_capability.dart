/// VerifySliceCapability (spec 043): slice integrity verification
/// (US6, FR-013..FR-015).
///
/// Fast mode checks that every import in the sandbox resolves (ImportVerifier);
/// analyze mode additionally runs `dart analyze` through an injectable
/// process seam. `cut --verify` reuses this capability and rolls the
/// sandbox back when verification fails.
library;

import 'dart:io';

import '../../../core/plugin_system/capability.dart';
import '../capabilities/cut_slice_capability.dart';
import '../verifier/analyze_runner.dart';
import '../verifier/import_verifier.dart';

/// Process execution seam for the analyzer (see [AnalyzeRunner]).
typedef AnalyzeLauncher = Future<ProcessResult> Function(
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
  }) : _importVerifier = importVerifier ?? ImportVerifier(),
       _analyzeRunner = analyzeRunner ?? AnalyzeRunner();

  final ImportVerifier _importVerifier;
  final AnalyzeRunner _analyzeRunner;

  @override
  String get name => 'verify_slice';

  @override
  String get description =>
      'Check that every import in a slice resolves (and optionally run the '
      'analyzer).';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'projectRoot': {'type': 'string'},
      'analyze': {'type': 'boolean'},
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
        ? Directory(sandboxDir)
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .length
        : 0;
    return EffectReport(
      planId: 'verify-$sliceName',
      pluginId: 'slice',
      capabilityName: name,
      args: args,
      changes: [
        Effect(file: sandboxDir, action: 'check $dartFiles dart file(s)'),
      ],
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
            '$sandboxDir. Run `zfa slice cut $sliceName --entry <point>` '
            'first.',
      );
    }

    final report = await _importVerifier.verify(
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
}
