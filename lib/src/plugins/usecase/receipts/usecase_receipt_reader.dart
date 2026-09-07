import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/project/receipt_store.dart';

/// SPEC 1119 — loads the latest standalone create receipt for an entity
/// (`.zfa/receipts/usecase-create-<entity>-<timestamp>.json`, issue
/// #1138 key shape). The verify/certify gates resolve their knobs
/// receipt-first, flags-override — the same resolution
/// `zfa service verify` uses.
class UsecaseReceiptReader {
  const UsecaseReceiptReader();

  /// The most recent parseable `usecase-create-<entity>-*.json` receipt,
  /// or null when none exists (corrupted documents are skipped — one
  /// broken receipt must not erase the provenance of healthy ones).
  GenerationReceipt? load(String projectRoot, String entity) {
    final dir = Directory(p.join(projectRoot, '.zfa', 'receipts'));
    if (!dir.existsSync()) return null;
    final prefix = 'usecase-create-${_sanitize(entity)}-';
    final files =
        dir.listSync().whereType<File>().where((f) {
            final base = p.basename(f.path);
            return base.startsWith(prefix) && base.endsWith('.json');
          }).toList()
          ..sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    for (final file in files) {
      try {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final receipt = GenerationReceipt.fromJson(json);
        // The provenance contract (issue #996): plugin + capability must
        // match the key shape we searched by.
        if (receipt.plugin != 'usecase') continue;
        if (receipt.capability != null && receipt.capability != 'create') {
          continue;
        }
        return receipt;
      } catch (_) {
        // Skip corrupted receipts.
      }
    }
    return null;
  }

  /// The receipt files entry whose basename is [fileName] — the
  /// project-relative path the create run bound the per-method file to.
  String? receiptPathFor(GenerationReceipt receipt, String fileName) {
    for (final entry in receipt.files) {
      final base = entry.path.replaceAll('\\', '/').split('/').last;
      if (base == fileName) return entry.path;
    }
    return null;
  }

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
