/// One survived mutant, cited by file + line (bug #837).
///
/// Plain data class living in `models/` so the model layer does not depend
/// on the service layer for it. `MutationVerifier` (services) re-exports it.
library;

class MutationSurvivor {
  const MutationSurvivor({required this.file, required this.line});

  final String file;
  final int line;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutationSurvivor && other.file == file && other.line == line);

  @override
  int get hashCode => Object.hash(file, line);

  @override
  String toString() => '$file:$line';
}
