/// `TddGenerationReceipts` — proof.v1 receipts for the TDD generation
/// verbs (issue #969, T003; reuses the #807 `ReceiptStore` machinery
/// `realize` already uses).
///
/// Every verb that writes an artifact records a digest-binding receipt
/// under `.zfa/receipts/` so `zfa proof check` can verify the byte state
/// of the whole TDD cycle: a full plan→gen→verify-red→make cycle leaves
/// every generated artifact self-certifying, and any hand-edit after the
/// fact shows up as digest drift.
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';

class TddGenerationReceipts {
  /// Persists one proof.v1 receipt covering [files] (absolute paths the
  /// verb just wrote, each mapped to its action — `create` for new
  /// artifacts, `update` for overwrites/appends).
  ///
  /// [input] carries the verb's context; `feature` is REQUIRED for the
  /// cycle verbs because `zfa tdd verify`'s preflight gate scopes the
  /// proof check to the feature's receipts through it.
  static Future<void> write({
    required String projectRoot,
    required String command,
    required String target,
    required String? feature,
    required Map<String, String> files,
    Map<String, Object?> input = const <String, Object?>{},
  }) async {
    final receiptFiles = <GenerationReceiptFile>[];
    for (final entry in files.entries) {
      final file = File(entry.key);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      receiptFiles.add(
        GenerationReceiptFile(
          path: _relativePosix(entry.key, projectRoot),
          action: entry.value,
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
        ),
      );
    }
    if (receiptFiles.isEmpty) return;
    await ReceiptStore(projectRoot: projectRoot).save(
      GenerationReceipt(
        command: command,
        target: target,
        repro: 'zfa $command',
        at: DateTime.now().toUtc(),
        generatorVersion: '6.1.0',
        input: {
          ...input,
          if (feature != null && feature.isNotEmpty) 'feature': feature,
        },
        files: receiptFiles,
      ),
    );
  }

  /// Best-effort variant for verbs where a receipt failure must never
  /// break the main flow (mirrors the nuance-receipt contract). Failures
  /// are reported on stderr so the loss is never silent.
  static Future<void> writeBestEffort({
    required String projectRoot,
    required String command,
    required String target,
    required String? feature,
    required Map<String, String> files,
    Map<String, Object?> input = const <String, Object?>{},
  }) async {
    try {
      await write(
        projectRoot: projectRoot,
        command: command,
        target: target,
        feature: feature,
        files: files,
        input: input,
      );
    } catch (e) {
      stderr.writeln(
        'zfa $command: warning: proof receipt not written '
        '($e) — re-run to restore the provenance record.',
      );
    }
  }

  static String _relativePosix(String filePath, String from) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: from)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
  }
}
