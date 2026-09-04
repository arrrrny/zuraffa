/// DependencyParity (feature 072, issue #960): realizes a real adapter
/// against the DECLARED contract — the parity source is the row, not
/// the mock.
///
/// Pure: declared signatures + adapter member shapes in, drift report
/// out. `zfa tdd realize --adapter <Name>` consumes this for dependency
/// rows (FR-009).
library;

import '../models/dependency_contract.dart';

/// The parity result: drifted (missing) declared members, each with the
/// fix hint naming the declared row.
class ParityReport {
  final List<String> driftedMembers;
  final String fixHint;

  bool get passed => driftedMembers.isEmpty;

  const ParityReport({required this.driftedMembers, required this.fixHint});
}

abstract final class DependencyParity {
  /// Check [adapterMembers] (member shapes like
  /// `signIn(String email, String password)` or `signOut()`) against
  /// the declared contract. Only member NAMES drive parity — the
  /// concrete parameter types live in the adapter's own signatures.
  static ParityReport check({
    required DependencyContract contract,
    required List<String> adapterMembers,
  }) {
    final adapterNames = adapterMembers
        .map((m) => m.trim().split('(').first.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    final drifted = [
      for (final s in contract.signatures)
        if (!adapterNames.contains(s.name)) s.name,
    ];
    final fixHint = drifted.isEmpty
        ? ''
        : '--> fix: implement ${drifted.join(", ")} on the real adapter '
              '— the declared contract row "${contract.name}" requires '
              'them (issue #960).';
    return ParityReport(driftedMembers: drifted, fixHint: fixHint);
  }
}
