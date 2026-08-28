import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

/// Biometrics built-in: port contract, scripted in-memory adapter, and
/// the service's availability safety net.
void main() {
  group('BiometricsPort — in-memory adapter', () {
    test('reports capability and enrolled modalities', () async {
      final port = InMemoryBiometricsAdapter();

      expect(await port.canCheck(), isTrue);
      expect(await port.availableBiometrics(), [BiometricKind.fingerprint]);

      port.canCheckFlag = false;
      port.biometrics = [];
      expect(await port.canCheck(), isFalse);
      expect(await port.availableBiometrics(), isEmpty);
    });

    test('authenticate resolves the scripted outcome and records the '
        'reason', () async {
      final port = InMemoryBiometricsAdapter();

      expect(await port.authenticate('Unlock vault'), isTrue);
      port.setNextOutcome(false);
      expect(await port.authenticate('Retry'), isFalse);
      expect(port.promptedReasons, ['Unlock vault', 'Retry']);
    });

    test('unavailable devices throw a typed error', () async {
      final port = InMemoryBiometricsAdapter()..canCheckFlag = false;

      await expectLater(
        port.authenticate('nope'),
        throwsA(
          isA<BiometricsException>().having(
            (e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );
    });

    test('cancelled and locked-out flows throw typed errors', () async {
      final port = InMemoryBiometricsAdapter()
        ..setNextOutcome(BiometricsException.cancelled());

      await expectLater(
        port.authenticate('unlock'),
        throwsA(
          isA<BiometricsException>().having((e) => e.code, 'code', 'cancelled'),
        ),
      );

      port.setNextOutcome(BiometricsException.lockedOut());
      await expectLater(
        port.authenticate('unlock'),
        throwsA(
          isA<BiometricsException>().having(
            (e) => e.code,
            'code',
            'locked_out',
          ),
        ),
      );
    });
  });

  group('BiometricsService', () {
    test(
      'authenticate returns false (no throw) on incapable devices',
      () async {
        final port = InMemoryBiometricsAdapter()..canCheckFlag = false;
        final service = BiometricsService(port: port);

        expect(
          await service.authenticate('unlock'),
          isFalse,
          reason:
              'the common incapable-device flow is a plain false, '
              'not an exception',
        );
      },
    );

    test(
      'isAvailable / availableBiometrics surface through the service',
      () async {
        final port = InMemoryBiometricsAdapter()
          ..biometrics = [BiometricKind.face, BiometricKind.fingerprint];
        final service = BiometricsService(port: port);

        expect(await service.isAvailable, isTrue);
        expect(await service.availableBiometrics, [
          BiometricKind.face,
          BiometricKind.fingerprint,
        ]);
      },
    );

    test('registerBiometricsDependencies wires port + service', () async {
      final getIt = GetIt.asNewInstance();
      final custom = InMemoryBiometricsAdapter();
      registerBiometricsDependencies(getIt, port: custom);

      final service = getIt<BiometricsService>();
      expect(
        await service.authenticate('di'),
        isTrue,
        reason: 'the injected adapter backs the service',
      );
      expect(custom.promptedReasons, ['di']);
    });
  });
}
