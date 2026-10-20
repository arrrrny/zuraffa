import 'package:test/test.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Bug 1962 — `GeneratorConfig.toJson → fromJson` round-trip always throws.
///
/// The `presenter` / `controller` JSON keys are overloaded with different
/// types on the two sides of the JSON surface: `toJson` emits
/// `'presenter': generatePresenter` / `'controller': generateController`
/// (both bool, always non-null), while `fromJson` read those same keys BOTH
/// ways — `json['presenter'] == true` (bool, fine) AND
/// `json['presenter'] ?? json['custom_presenter_name']` (String? read). The
/// non-null bool short-circuits the `??` fallback and lands in a `String?`
/// field → `type 'bool' is not a subtype of type 'String?'` on EVERY full
/// round-trip.
///
/// Fix: `fromJson` reads only the dedicated `custom_presenter_name` /
/// `custom_controller_name` keys; the bool keys stay bool-only. `toJson`
/// never emitted a String under the bool keys, so no producer loses data.
void main() {
  group('bug 1962 — GeneratorConfig JSON round-trip', () {
    test('plain CRUD config reconstructs from its own toJson', () {
      final config = GeneratorConfig(
        name: 'Deal',
        outputDir: 'lib/src',
        methods: ['get'],
        generateMock: true,
      );

      final restored = GeneratorConfig.fromJson(config.toJson(), config.name);

      expect(restored.name, 'Deal');
      expect(restored.methods, ['get']);
      expect(restored.generateMock, isTrue);
      expect(restored.generatePresenter, isFalse);
      expect(restored.generateController, isFalse);
      expect(restored.customPresenterName, isNull);
      expect(restored.customControllerName, isNull);
    });

    test('custom presenter/controller names survive the round-trip', () {
      final config = GeneratorConfig(
        name: 'Deal',
        outputDir: 'lib/src',
        methods: ['get'],
        customPresenterName: 'MyDealPresenter',
        customControllerName: 'MyDealController',
      );

      final restored = GeneratorConfig.fromJson(config.toJson(), config.name);

      expect(restored.customPresenterName, 'MyDealPresenter');
      expect(restored.customControllerName, 'MyDealController');
    });

    test('presenter/controller bools survive the round-trip', () {
      final config = GeneratorConfig(
        name: 'Deal',
        outputDir: 'lib/src',
        methods: ['get'],
        generatePresenter: true,
        generateController: true,
      );

      final restored = GeneratorConfig.fromJson(config.toJson(), config.name);

      expect(restored.generatePresenter, isTrue);
      expect(restored.generateController, isTrue);
      expect(restored.customPresenterName, isNull);
      expect(restored.customControllerName, isNull);
    });
  });
}
