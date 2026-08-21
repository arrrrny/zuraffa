/// Lifecycle scope for registered dependencies.
enum DependencyScope {
  /// Single instance shared across the app.
  singleton,

  /// New instance created on every resolution.
  transient,

  /// Created on first resolution, then cached.
  lazy,
}
