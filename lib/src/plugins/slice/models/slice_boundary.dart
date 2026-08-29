/// SliceBoundary model (spec 043 data model).
library;

/// An abstract interface at the edge of the slice where traversal stopped.
class SliceBoundary {
  /// Creates a boundary record.
  const SliceBoundary({
    required this.typeName,
    required this.interfaceFile,
    this.diRegistrationFile,
    this.mockStrategy = 'auto',
  });

  /// The abstract type name (e.g. `CustomerRepository`).
  final String typeName;

  /// Path to the abstract interface file (relative to project root).
  final String interfaceFile;

  /// Path to the DI file registering the concrete implementation, if found.
  final String? diRegistrationFile;

  /// How to mock: `auto` (generate stub), `existing` (project mock), `none`.
  final String mockStrategy;
}
