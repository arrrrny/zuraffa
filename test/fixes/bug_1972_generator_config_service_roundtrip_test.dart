import 'package:test/test.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Bug 1972 — `GeneratorConfig.toJson()` never emits a producer for the
/// `generateService` / `useService` bool flags, and it overloads the
/// `'service'` key with the service **name** (a `String?`) that `fromJson()`
/// also reads as a **bool**. After a `toJson()` → `fromJson()` round-trip
/// both flags silently revert to `false`.
///
/// Write side (`toJson()`): `'service': service` — the name only; no
/// `'generate_service'`, no `'use_service'` key.
///
/// Read side (`fromJson()`): `generateService: json['service'] == true ||
/// json['generate_service'] == true` — the name string is never `== true`, so
/// the flag can only come from the dedicated key, which nothing writes;
/// `useService` is not read from any key at all.
///
/// Fix: dedicated `'generate_service'` / `'use_service'` keys on the write
/// side, matching reads on the read side; the `'service'` key keeps carrying
/// the name.
void main() {
  group('bug 1972 — GeneratorConfig service flags round-trip', () {
    test('toJson emits the generate_service and use_service keys', () {
      final config = GeneratorConfig(
        name: 'Product',
        generateService: true,
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final json = config.toJson();

      expect(
        json.containsKey('generate_service'),
        isTrue,
        reason:
            "toJson must carry 'generate_service': fromJson reads the flag "
            'from that key, and the overloaded \'service\' key holds the '
            'name (a String?, never == true), so a missing producer '
            'silently clears the flag on replay',
      );
      expect(
        json.containsKey('use_service'),
        isTrue,
        reason:
            "toJson must carry 'use_service': fromJson reads the flag from "
            'that key, so a missing producer silently clears it on replay',
      );
      expect(json['generate_service'], isTrue);
      expect(json['use_service'], isTrue);
    });

    test('generateService: true survives toJson -> fromJson', () {
      final config = GeneratorConfig(
        name: 'Product',
        generateService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(
        replayed.generateService,
        isTrue,
        reason: 'the round-trip must preserve the service-generation flag',
      );
    });

    test('useService: true survives toJson -> fromJson', () {
      final config = GeneratorConfig(
        name: 'Product',
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(
        replayed.useService,
        isTrue,
        reason: 'the round-trip must preserve the use-service flag',
      );
    });

    test('the service name survives the round-trip', () {
      final config = GeneratorConfig(
        name: 'Product',
        service: 'AuthService',
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(replayed.service, 'AuthService');
      expect(replayed.effectiveService, 'AuthService');
      expect(replayed.serviceSnake, 'auth_service');
    });

    test('a service name does not flip generateService', () {
      // The overload: the name lives under 'service', the flag used to be
      // read from the same key as a bool. A name is never `== true`, so the
      // flag must come from the dedicated key only.
      final config = GeneratorConfig(
        name: 'Product',
        service: 'AuthService',
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(replayed.generateService, isFalse);
      expect(replayed.useService, isFalse);
    });

    test('useService: true keeps hasService and the service name fallback', () {
      final config = GeneratorConfig(
        name: 'Product',
        useService: true,
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');

      expect(
        replayed.hasService,
        isTrue,
        reason: 'hasService keys off useService — the loss was silent here',
      );
      expect(replayed.effectiveService, 'ProductService');
      expect(replayed.serviceSnake, 'product_service');
    });

    test('default (false) flags still round-trip as false', () {
      final config = GeneratorConfig(
        name: 'Product',
        outputDir: GeneratorConfig.fixedOutputDir,
      );

      final json = config.toJson();
      expect(json['generate_service'], isFalse);
      expect(json['use_service'], isFalse);

      final replayed = GeneratorConfig.fromJson(json, 'Product');
      expect(replayed.generateService, isFalse);
      expect(replayed.useService, isFalse);
      expect(replayed.hasService, isFalse);
    });

    test('explicit generate_service/use_service external JSON parses true', () {
      final config = GeneratorConfig.fromJson({
        'generate_service': true,
        'use_service': true,
      }, 'Product');

      expect(config.generateService, isTrue);
      expect(config.useService, isTrue);
    });
  });
}
