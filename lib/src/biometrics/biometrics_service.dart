import 'package:get_it/get_it.dart';

import 'biometrics.dart';

export 'biometrics.dart';

/// App-facing biometrics facade with a permission-free safety net.
///
/// ```dart
/// final biometrics = BiometricsService();
/// if (await biometrics.isAvailable) {
///   final ok = await biometrics.authenticate('Unlock your vault');
/// }
/// ```
class BiometricsService {
  /// The platform adapter (or the in-memory default in tests).
  final BiometricsPort port;

  BiometricsService({BiometricsPort? port})
    : port = port ?? InMemoryBiometricsAdapter();

  /// Whether the device can authenticate with biometrics.
  Future<bool> get isAvailable => port.canCheck();

  /// Enrolled modalities (empty when none).
  Future<List<BiometricKind>> get availableBiometrics =>
      port.availableBiometrics();

  /// Prompts authentication with [reason]. Returns `false` (never throws
  /// for the common flows) when the device cannot check biometrics —
  /// callers gate on [isAvailable] for messaging; genuine failures
  /// (cancelled/locked-out) still throw typed [BiometricsException]s so
  /// callers can route to fallback credential auth.
  Future<bool> authenticate(String reason) async {
    if (!await port.canCheck()) return false;
    return port.authenticate(reason);
  }
}

/// Registers the biometrics stack onto [getIt].
void registerBiometricsDependencies(GetIt getIt, {BiometricsPort? port}) {
  getIt
    ..registerLazySingleton<BiometricsPort>(
      () => port ?? InMemoryBiometricsAdapter(),
    )
    ..registerLazySingleton<BiometricsService>(
      () => BiometricsService(port: getIt<BiometricsPort>()),
    );
}
