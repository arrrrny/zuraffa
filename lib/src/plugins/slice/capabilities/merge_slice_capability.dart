/// MergeSliceCapability (spec 043): merge-back (US2, FR-008).
///
/// Plan: preview which files would be copied, conflicted, or deleted.
/// Execute: run the merger and surface its report.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/plugin_system/capability.dart';
import '../capabilities/cut_slice_capability.dart';
import '../generators/manifest_writer.dart';
import '../merger/conflict_detector.dart';
import '../merger/slice_merger.dart';
import '../models/slice_file.dart';
import '../models/slice_manifest.dart';

/// Merge agent changes from a slice back into the main project.
class MergeSliceCapability implements ZuraffaCapability {
  /// Creates the capability with injectable collaborators.
  MergeSliceCapability({ManifestWriter? manifestWriter, SliceMerger? merger})
    : _manifestWriter = manifestWriter ?? ManifestWriter(),
       _merger = merger ?? SliceMerger();

  final ManifestWriter _manifestWriter;
  final SliceMerger _merger;

  @override
  String get name => 'merge_slice';

  @override
  String get description =>
      'Merge agent modifications from a slice sandbox back into the project.';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'name': {'type': 'string'},
      'projectRoot': {'type': 'string'},
      'confirmAll': {'type': 'boolean'},
    },
  };

  @override
  JsonSchema get outputSchema => {
    'type': 'object',
    'properties': {
      'success': {'type': 'boolean'},
      'copied': {'type': 'array', 'items': {'type': 'string'}},
      'conflicts': {'type': 'array', 'items': {'type': 'string'}},
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
        final mainHash = _hashIfExists(
          p.join(projectRoot, file.relativePath),
        );
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
              MergeDecision.safeCopy => file.ownership == FileOwnership.shared
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
    final confirmOverwrite =
        args['confirmSharedOverwrite'] as bool Function(SliceFile)? ??
        (_) => confirmAll;
    final confirmDelete =
        args['confirmSharedDelete'] as bool Function(String)? ??
        (_) => confirmAll;

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

    final SliceManifest manifest;
    try {
      manifest = await _manifestWriter.read(sandboxDir);
    } on SliceManifestError catch (e) {
      return ExecutionResult(success: false, message: e.message);
    }

    final report = await _merger.merge(
      manifest: manifest,
      sandboxDir: sandboxDir,
      projectRoot: projectRoot,
      confirmSharedOverwrite: confirmOverwrite,
      confirmSharedDelete: confirmDelete,
    );

    final success = report.noChanges || report.clean;
    return ExecutionResult(
      success: success,
      files: [...report.copied, ...report.created],
      message: report.message,
      data: {
        'copied': report.copied,
        'created': report.created,
        'deleted': report.deleted,
        'conflicts': report.conflicts,
        'unconfirmedShared': report.unconfirmedShared,
        'warnings': report.warnings,
        'skipped': report.skipped,
      },
    );
  }

  String? _hashIfExists(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    return sha256.convert(file.readAsBytesSync()).toString();
  }
}
