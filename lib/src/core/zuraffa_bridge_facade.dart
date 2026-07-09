/// Thin facade that exposes the subset of Zuraffa configuration that
/// ZuraffaApiBridge needs, without importing the full zuraffa.dart barrel.
///
/// This avoids a circular dependency:
///   zuraffa.dart → api_bridge.dart → zuraffa.dart
///
/// The `Zuraffa` class in zuraffa.dart writes to [enableApiInProfile] and
/// ZuraffaApiBridge reads from it.
abstract class ZuraffaBridgeFacade {
  /// Whether the API bridge is active in profile mode.
  ///
  /// Defaults to false — profile mode is opt-in.
  /// Set this to true before calling ZuraffaApiBridge.init() to enable the
  /// bridge in profile builds.
  static bool enableApiInProfile = false;
}
