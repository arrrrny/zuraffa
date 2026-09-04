/// ExportSliceCapability (spec 043): slice export orchestration (US8,
/// FR-017..FR-020).
///
/// Runs the fast verification gate FIRST (FR-020): an incomplete slice never
/// produces an artifact. Then filters the pubspec down to what the slice
/// uses and delegates to [TarballExporter] (`tar.gz`) or [GithubExporter]
/// (`github`), recording the repo URL in the manifest's `exportedTo` field.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/context/progress_reporter.dart';
import '../../../core/plugin_system/capability.dart';
import '../capabilities/cut_slice_capability.dart';
import '../exporter/github_exporter.dart';
import '../exporter/pubspec_filter.dart';
import '../exporter/tarball_exporter.dart';
import '../generators/manifest_writer.dart';
import '../models/slice_manifest.dart';
import '../verifier/import_verifier.dart';

/// Exports a verified slice as a tarball or a private GitHub repo.
class ExportSliceCapability implements ZuraffaCapability {
  /// Creates the capability with injectable collaborators.
  ExportSliceCapability({
    ImportVerifier? importVerifier,
    PubspecFilter? pubspecFilter,
    TarballExporter? tarballExporter,
    GithubExporter? githubExporter,
    ManifestWriter? manifestWriter,
  }) : _importVerifier = importVerifier ?? ImportVerifier(),
       _pubspecFilter = pubspecFilter ?? PubspecFilter(),
       _tarballExporter = tarballExporter ?? TarballExporter(),
       _githubExporter = githubExporter ?? GithubExporter(),
       _manifestWriter = manifestWriter ?? ManifestWriter();

  final ImportVerifier _importVerifier;
  final PubspecFilter _pubspecFilter;
  final TarballExporter _tarballExporter;
  final GithubExporter _githubExporter;
  final ManifestWriter _manifestWriter;

  /// Directory (relative to the project root) where tarballs land.
  static const exportsDirName = '.zuraffa/exports';

  @override
  String get name => 'export_slice';

  @override
  String get description =>
      'Export a verified slice as a tar.gz archive or a private GitHub '
      'repository.';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'required': ['name', 'format'],
    'properties': {
      'name': {'type': 'string'},
      'format': {
        'type': 'string',
        'enum': ['tar.gz', 'github'],
      },
      'projectRoot': {'type': 'string'},
      'repo': {'type': 'string'},
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'success': {'type': 'boolean'},
      'archivePath': {'type': 'string'},
      'repoUrl': {'type': 'string'},
    },
  };

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final format = args['format'] as String? ?? 'tar.gz';
    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    return EffectReport(
      planId: 'export-$sliceName',
      pluginId: 'slice',
      capabilityName: name,
      args: args,
      changes: [
        Effect(
          file: format == 'github'
              ? 'github: $sandboxDir'
              : '$sandboxDir -> $exportsDirName/$sliceName.tar.gz',
          action: 'export ($format)',
        ),
      ],
    );
  }

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async {
    final projectRoot =
        args['projectRoot'] as String? ?? Directory.current.path;
    final sliceName = args['name'] as String;
    final format = SliceExportFormat.parse(args['format'] as String);
    final repo = args['repo'] as String?;
    final ghLauncher = args['ghLauncher'] as GhLauncher?;
    final progress =
        args['progressReporter'] as ProgressReporter? ?? NullProgressReporter();

    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    if (!Directory(sandboxDir).existsSync()) {
      return ExecutionResult(
        success: false,
        message:
            'No slice named "$sliceName" found at '
            '${p.relative(sandboxDir, from: projectRoot)}. Run `zfa slice cut '
            '$sliceName --entry <point>` first.',
      );
    }

    // Verification gate (FR-020): never export a broken slice.
    progress.update('verifying the slice');
    final report = _importVerifier.verify(
      sandboxDir: sandboxDir,
      projectRoot: projectRoot,
    );
    if (!report.passed) {
      return ExecutionResult(
        success: false,
        message:
            'Verification failed with ${report.issues.length} unresolved '
            'import(s) — the slice is NOT exportable.',
        data: {
          'aborted': true,
          'issues': [
            for (final issue in report.issues)
              {
                'file': issue.file,
                'line': issue.line,
                'importPath': issue.importPath,
                'reason': issue.reason,
              },
          ],
        },
      );
    }

    final manifest = await _manifestWriter.read(sandboxDir);
    final sliceDartFiles = <String>[
      for (final file in manifest.files)
        if (file.relativePath.endsWith('.dart')) file.relativePath,
      for (final generated in manifest.generatedFiles)
        if (generated.endsWith('.dart')) generated,
    ];
    progress.update('filtering pubspec.yaml down to the slice');
    final pubspecContent = await _pubspecFilter.filter(
      projectRoot: projectRoot,
      sandboxDir: sandboxDir,
      sliceDartFiles: sliceDartFiles,
    );

    if (format == SliceExportFormat.tarGz) {
      progress.update('building the tar.gz archive');
      final outputPath = _exportsPath(projectRoot, sliceName);
      final archivePath = await _tarballExporter.export(
        sandboxDir: sandboxDir,
        outputPath: outputPath,
        pubspecContent: pubspecContent,
      );
      return ExecutionResult(
        success: true,
        message:
            'Exported slice "$sliceName" to '
            '${p.relative(archivePath, from: projectRoot)} '
            '(${report.filesChecked} dart file(s), filtered pubspec).',
        data: {'archivePath': archivePath},
      );
    }

    progress.update('creating and pushing the GitHub repository');
    final exporter = ghLauncher != null
        ? GithubExporter(ghLauncher: ghLauncher)
        : _githubExporter;
    final result = await exporter.export(
      sandboxDir: sandboxDir,
      repo: repo,
      packageName: manifest.packageName,
      sliceName: sliceName,
      pubspecContent: pubspecContent,
    );
    if (!result.success) {
      return ExecutionResult(
        success: false,
        message: result.message ?? 'GitHub export failed.',
        data: {'aborted': true},
      );
    }

    // Record the repo URL in slice.yaml (FR-004 exportedTo).
    await _manifestWriter.write(
      manifest.copyWith(exportedTo: result.repoUrl),
      sandboxDir,
    );
    return ExecutionResult(
      success: true,
      message: result.message,
      data: {'repoUrl': result.repoUrl, 'exportedTo': result.repoUrl},
    );
  }

  /// Tarball output path for [sliceName] under the project root.
  static String _exportsPath(String projectRoot, String sliceName) =>
      '$projectRoot/$exportsDirName/$sliceName.tar.gz';
}
