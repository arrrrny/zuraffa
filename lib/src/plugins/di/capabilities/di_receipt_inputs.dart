import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;

import '../../../models/generated_file.dart';

/// Provenance inputs the standalone DI capabilities expose for the
/// receipt writer (spec 0974 order 3, as reworked by issue #1130).
///
/// The capabilities NO LONGER write their own receipt: since issue #1130
/// the [CapabilityInvocationWrapper] is the sole receipt writer on the
/// standalone path (a second writer races it and shadows the canonical
/// document in `ReceiptStore.loadAll()`). The DI contract's extra
/// payload — the aggregate DI index digest map — is surfaced through
/// `args['_indexFiles']` instead, and the wrapper aliases it to the
/// public `indexFiles` key of the proof.v1 `input` map.
class DiReceiptInputs {
  DiReceiptInputs._();

  /// Actions that mean bytes actually landed on disk this run. Skipped
  /// files kept their previous bytes; deleted files have none — neither
  /// proves this run's generation.
  static const _writtenActions = {'created', 'overwritten', 'updated'};

  /// Whether [files] contain anything a receipt can bind.
  static bool hasWritableOutput(List<GeneratedFile> files) =>
      files.any((f) => _writtenActions.contains(f.action));

  /// The aggregate registration state: sha256 of every DI `index.dart`
  /// this run (re)wrote, keyed by project-relative POSIX path — the
  /// map a consumer can compare against the live index bytes.
  static Map<String, String> indexHashes(
    List<GeneratedFile> files,
    String projectRoot,
  ) {
    final hashes = <String, String>{};
    for (final file in files) {
      if (!file.path.endsWith('index.dart')) continue;
      final absolute = path.isAbsolute(file.path)
          ? file.path
          : path.join(projectRoot, file.path);
      final f = File(absolute);
      if (!f.existsSync()) continue;
      hashes[file.path.replaceAll('\\', '/')] = crypto.sha256
          .convert(f.readAsBytesSync())
          .toString();
    }
    return hashes;
  }
}
