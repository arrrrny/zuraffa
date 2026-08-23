/// Biometric authentication seam (the auth enabler from the ecosystem
/// analysis): can the device check biometrics, and can the user
/// authenticate right now.
///
/// [BiometricsPort] is the technology-agnostic contract platform adapters
/// (Face ID / fingerprint) implement; [InMemoryBiometricsAdapter] is the
/// pure-Dart default so biometric flows test without a device.
library;

/// The biometric modalities a device can report.
enum BiometricKind { none, fingerprint, face, iris, voice }

/// Recoverable, typed biometrics error.
class BiometricsException implements Exception {
  /// Machine-readable reason, stable across releases.
  final String code;

  /// Human-readable description.
  final String message;

  const BiometricsException(this.code, this.message);

  /// The user cancelled the prompt.
  factory BiometricsException.cancelled() =>
      const BiometricsException('cancelled', 'Biometric prompt was cancelled.');

  /// The device cannot perform biometric authentication.
  factory BiometricsException.unavailable() => const BiometricsException(
    'unavailable',
    'No biometric authentication is available on this device.',
  );

  /// The user failed verification too many times (device lockout).
  factory BiometricsException.lockedOut() => const BiometricsException(
    'locked_out',
    'Biometrics is locked out; '
        'authenticate with the device credential first.',
  );

  @override
  String toString() => 'BiometricsException($code): $message';
}

/// The biometrics contract.
abstract class BiometricsPort {
  /// Whether the device has enrolled biometrics and can authenticate.
  Future<bool> canCheck();

  /// The modalities enrolled on the device (empty when none).
  Future<List<BiometricKind>> availableBiometrics();

  /// Prompts the user to authenticate with [reason]; resolves `true` on
  /// success, `false` on a mismatch, and throws [BiometricsException]
  /// for cancelled/locked-out/unavailable flows.
  Future<bool> authenticate(String reason);
}

/// Pure-Dart default adapter (test/dev): scripted outcomes.
class InMemoryBiometricsAdapter implements BiometricsPort {
  /// Whether the device reports biometric capability.
  bool canCheckFlag = true;

  /// Modalities [availableBiometrics] reports.
  List<BiometricKind> biometrics = [BiometricKind.fingerprint];

  /// The outcome the next [authenticate] resolves with (`true`/`false`),
  /// or a [BiometricsException] to throw. Defaults to success.
  Object /* bool | BiometricsException */ nextOutcome = true;

  /// Reasons the adapter was asked to authenticate with (introspection).
  final List<String> promptedReasons = [];

  @override
  Future<bool> canCheck() async => canCheckFlag;

  @override
  Future<List<BiometricKind>> availableBiometrics() async =>
      List.unmodifiable(biometrics);

  @override
  Future<bool> authenticate(String reason) async {
    promptedReasons.add(reason);
    if (!canCheckFlag) {
      throw BiometricsException.unavailable();
    }
    final outcome = nextOutcome;
    if (outcome is BiometricsException) {
      throw outcome;
    }
    return outcome as bool;
  }

  /// Scripting helpers: [outcome] is `true`/`false` or an exception.
  void setNextOutcome(Object outcome) {
    nextOutcome = outcome;
  }
}
