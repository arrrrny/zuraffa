/// Extraction depth (spec 043 data model).
library;

/// Controls how deep the dependency graph traversal goes (FR-002).
enum SliceDepth {
  /// View, controller, state only.
  view,

  /// Adds the presenter.
  presentation,

  /// Adds domain (usecases, interfaces, entities). The default.
  feature,

  /// Adds data implementations. No mocks.
  full;

  /// Parses a depth name, throwing [ArgumentError] on unknown values.
  static SliceDepth parse(String name) {
    return switch (name) {
      'view' => SliceDepth.view,
      'presentation' => SliceDepth.presentation,
      'feature' => SliceDepth.feature,
      'full' => SliceDepth.full,
      _ => throw ArgumentError.value(name, 'name', 'Unknown slice depth'),
    };
  }
}
