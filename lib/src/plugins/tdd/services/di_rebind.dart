/// `DiRebinder` — swaps a generated mock datasource binding for the real
/// adapter behind the SAME generated interface (spec 913, phase 1).
///
/// STUB (red phase): every member throws until the green phase implements
/// the rebind contract.
library;

/// Raised when the rebind cannot proceed honestly: no mock binding to
/// swap, adapter class not found (no auto-generation of real impls), or a
/// domain/ file would have to change (contract change is forbidden).
class DiRebindException implements Exception {
  const DiRebindException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One file's binding sites: how many mock-class references were swapped.
class DiBindingSite {
  const DiBindingSite({required this.file, required this.occurrences});
  final String file;
  final int occurrences;
}

/// The result of a successful rebind.
class DiRebindResult {
  const DiRebindResult({
    required this.entity,
    required this.mockClass,
    required this.adapterClass,
    required this.adapterFile,
    required this.sites,
    required this.interfaceFilesUntouched,
  });

  final String entity;

  /// The mock datasource class that was unbound (e.g.
  /// `UserMockDataSource`).
  final String mockClass;

  /// The real adapter class now bound (e.g. `UserRealAdapter`).
  final String adapterClass;

  /// Absolute path of the file declaring the adapter class.
  final String adapterFile;

  /// Per-file swapped binding sites.
  final List<DiBindingSite> sites;

  /// The generated interface layer files verified byte-identical across
  /// the swap (the same-interface proof).
  final List<String> interfaceFilesUntouched;
}

class DiRebinder {
  DiRebinder({required this.projectRoot});

  /// The target project root.
  final String projectRoot;

  /// Find the mock binding sites for [entity] under `lib/`: files whose
  /// text references the mock datasource class.
  Future<List<DiBindingSite>> scan({required String entity}) =>
      throw UnimplementedError();

  /// Resolve the file declaring [adapterClass], or throw
  /// [DiRebindException] — the command never generates real impls.
  Future<String> locateAdapter({required String adapterClass}) =>
      throw UnimplementedError();

  /// Swap every mock binding site to the real adapter: symbol replacement
  /// in the binding files, import fixup, and a byte-identity proof that no
  /// `domain/` (interface) file changed.
  Future<DiRebindResult> rebind({
    required String entity,
    required String adapterClass,
  }) => throw UnimplementedError();
}
