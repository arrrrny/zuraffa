import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import '../../../core/project/receipt_store.dart';
import '../../../models/generated_file.dart';
import '../../../version.dart';

/// SPEC 0974 (issue #974, order 3): proof-carrying generation for the
/// STANDALONE `zfa di create|register` path.
///
/// The `zfa make` path has shipped receipts since issue #807
/// (`PluginManager._persistGenerationReceipt`); the standalone path wrote
/// nothing, so a `zfa di create` run had no provenance. This writer appends
/// the same `proof.v1` receipt through [ReceiptStore] — registrations
/// written with final on-disk digests plus the DI index hashes — so
/// `zfa proof check` verifies standalone runs identically.
///
/// Best-effort by design (mirrors the make path): a receipt failure
/// degrades to a warning instead of failing an otherwise-successful
/// generation.
class DiReceiptWriter {
  final String projectRoot;

  const DiReceiptWriter({required this.projectRoot});

  /// Actions that mean bytes actually landed on disk this run. Skipped
  /// files kept their previous bytes; deleted files have none — neither
  /// proves this run's generation.
  static const _writtenActions = {'created', 'overwritten', 'updated'};

  /// Whether [files] contain anything a receipt can bind.
  static bool hasWritableOutput(List<GeneratedFile> files) =>
      files.any((f) => _writtenActions.contains(f.action));

  /// Appends the `di-<target>` receipt for a standalone capability run.
  ///
  /// [capability] is `create` or `register`; [target] is the entity or
  /// class name the run was about; [args] is the effective capability
  /// argument map (recorded as the receipt's input context).
  Future<void> writeReceipt({
    required String capability,
    required String target,
    required Map<String, dynamic> args,
    required List<GeneratedFile> files,
  }) async {
    try {
      final written = files
          .where((f) => _writtenActions.contains(f.action))
          .toList();

      final entries = <GenerationReceiptFile>[];
      for (final file in written) {
        final absolute = path.isAbsolute(file.path)
            ? file.path
            : path.join(projectRoot, file.path);
        final f = File(absolute);
        if (!f.existsSync()) continue;
        final bytes = f.readAsBytesSync();
        final keepSnapshot =
            bytes.length <= ReceiptStore.maxSnapshotBytes &&
            !_isLikelyBinary(bytes);
        entries.add(
          GenerationReceiptFile(
            path: _projectRelative(absolute),
            action: file.action,
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: keepSnapshot ? f.readAsStringSync() : null,
          ),
        );
      }
      if (entries.isEmpty) return;
      entries.sort((a, b) => a.path.compareTo(b.path));

      // Index hash: the DI index files this run (re)wrote, digested —
      // the aggregate registration state a consumer can compare against.
      final indexHashes = <String, String>{};
      for (final entry in entries) {
        if (entry.path.endsWith('index.dart')) {
          indexHashes[entry.path] = entry.sha256;
        }
      }

      await ReceiptStore(projectRoot: projectRoot).save(
        GenerationReceipt(
          command: 'di',
          target: target,
          repro: 'zfa di $capability $target',
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: {
            'plugin': 'di',
            'capability': capability,
            ...args,
            'index_files': indexHashes,
          },
          files: entries,
        ),
      );
    } catch (e) {
      print('⚠️  Generation receipt not written: $e');
    }
  }

  String _projectRelative(String absolute) =>
      path.relative(absolute, from: projectRoot).replaceAll('\\', '/');

  /// Snapshots are diffed as text; refuse to store bytes that are not
  /// valid UTF-8 text (defensive — generated outputs are text).
  static bool _isLikelyBinary(List<int> bytes) {
    final probe = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    try {
      utf8.decode(probe);
      return false;
    } on FormatException {
      return true;
    }
  }
}
