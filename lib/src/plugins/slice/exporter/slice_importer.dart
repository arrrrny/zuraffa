/// SliceImporter (spec 043): pull an exported slice back (US8, FR-019).
///
/// Reads the `exportedTo` URL from the sandbox's `slice.yaml`, clones the
/// exported repository into a temp directory (through an injectable process
/// seam), and copies its contents over the local sandbox — overwriting
/// sandbox files so the result is ready for `zfa slice merge`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../capabilities/cut_slice_capability.dart';
import '../generators/manifest_writer.dart';
import 'github_exporter.dart';

/// The outcome of an import.
class SliceImportResult {
  /// Creates the result.
  const SliceImportResult({
    required this.success,
    this.message,
    this.filesImported = 0,
  });

  /// Whether the pull succeeded.
  final bool success;

  /// Human-readable summary or error.
  final String? message;

  /// Number of files copied over the sandbox.
  final int filesImported;
}

/// Pulls an exported slice repository back over the local sandbox.
class SliceImporter {
  /// Creates the importer with injectable collaborators.
  SliceImporter({GhLauncher? ghLauncher, ManifestWriter? manifestWriter})
    : _launcher = ghLauncher ?? _defaultLauncher,
      _manifestWriter = manifestWriter ?? ManifestWriter();

  final GhLauncher _launcher;
  final ManifestWriter _manifestWriter;

  static Future<ProcessResult> _defaultLauncher(
    List<String> args, {
    String? workingDirectory,
  }) {
    if (args.first == 'git') {
      return Process.run(
        'git',
        args.sublist(1),
        workingDirectory: workingDirectory,
      );
    }
    return Process.run('gh', args, workingDirectory: workingDirectory);
  }

  /// Imports the slice [sliceName] cut from [projectRoot].
  Future<SliceImportResult> importSlice({
    required String sliceName,
    required String projectRoot,
  }) async {
    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    if (!Directory(sandboxDir).existsSync()) {
      return SliceImportResult(
        success: false,
        message:
            'No slice named "$sliceName" found at '
            '${p.relative(sandboxDir, from: projectRoot)}. Run `zfa slice '
            'cut $sliceName --entry <point>` first.',
      );
    }

    final manifest = await _manifestWriter.read(sandboxDir);
    final exportedTo = manifest.exportedTo;
    if (exportedTo == null || exportedTo.isEmpty) {
      return SliceImportResult(
        success: false,
        message:
            'Slice "$sliceName" has no exportedTo URL in its slice.yaml — '
            'run `zfa slice export $sliceName --format github` first.',
      );
    }

    // Clone the exported repo into a scratch directory.
    final scratch = await Directory.systemTemp.createTemp('slice_import_');
    try {
      final clone = await _launcher([
        'git',
        'clone',
        exportedTo,
        scratch.path,
      ]);
      if (clone.exitCode != 0) {
        final output = '${clone.stdout}${clone.stderr}'.trim();
        return SliceImportResult(
          success: false,
          message:
              'Could not clone $exportedTo (${clone.exitCode}): '
              '${output.isEmpty ? 'no output' : output}',
        );
      }

      // Copy the cloned contents over the sandbox, overwriting files (U63).
      var copied = 0;
      for (final entity in Directory(scratch.path).listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: scratch.path);
        if (rel.split(p.separator).contains('.git')) continue;
        final target = p.join(sandboxDir, rel);
        await File(target).parent.create(recursive: true);
        await File(target).writeAsBytes(await entity.readAsBytes());
        copied++;
      }
      return SliceImportResult(
        success: true,
        filesImported: copied,
        message:
            'Imported $copied file(s) from $exportedTo over slice '
            '"$sliceName" — run `zfa slice verify $sliceName` next, then '
            '`zfa slice merge $sliceName`.',
      );
    } finally {
      if (await scratch.exists()) {
        await scratch.delete(recursive: true);
      }
    }
  }
}
