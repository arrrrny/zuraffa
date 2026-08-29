/// OwnershipClassifier (spec 043): owned vs shared (FR-010).
library;

import '../models/slice_file.dart';

/// Classifies slice files as owned (safe to modify) or shared (caution).
///
/// A file is `owned` exactly when it lives under one of the slice's entry
/// page directories (`lib/src/presentation/pages/<feature>/`); everything
/// else reachable from the entries — entities, domain interfaces, shared
/// widgets, DI wiring, core/ and config/ — is `shared` because other
/// features may depend on it (U27, U28).
class OwnershipClassifier {
  /// Classifies [relativePath] against the [entryPageDirs] (lib-relative,
  /// e.g. `lib/src/presentation/pages/product`).
  FileOwnership classify({
    required String relativePath,
    required List<String> entryPageDirs,
  }) {
    final normalized = relativePath.replaceAll('\\', '/');
    for (final dir in entryPageDirs) {
      final prefix = '${dir.replaceAll('\\', '/')}/';
      if (normalized.startsWith(prefix)) {
        return FileOwnership.owned;
      }
    }
    return FileOwnership.shared;
  }
}
