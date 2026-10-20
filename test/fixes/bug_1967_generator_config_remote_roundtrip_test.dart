import 'package:test/test.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// Bug 1967 — `GeneratorConfig.toJson()` never emits a `'remote'` key while
/// `fromJson()` reads `generateRemote: json['remote'] != false`. A config
/// with `generateRemote: false` therefore silently comes back as
/// `generateRemote: true` after a `toJson` → `fromJson` round-trip, and a
/// replayed config re-enables remote data-source generation the user
/// deliberately disabled.
///
/// Fix: emit `'remote': generateRemote` from `toJson()` alongside the other
/// bool flags (read side unchanged — the #1965 shape stays pinned).
///
/// The round-trip on master additionally crashed before the remote flag was
/// even reachable: `fromJson()` read the custom presenter/controller names
/// from the same `'presenter'`/`'controller'` keys `toJson()` emits as
/// bools (`type 'bool' is not a subtype of type 'String?'`). Fixed with the
/// dedicated-key read the #1962 branch (`25f7231`) established; the last
/// two tests pin that unblocking fix.
void main() {
  test('bug 1967: toJson emits the remote key fromJson reads', () {
    final config = GeneratorConfig(
      name: 'Product',
      generateRemote: false,
      outputDir: GeneratorConfig.fixedOutputDir,
    );

    final json = config.toJson();
    expect(
      json.containsKey('remote'),
      isTrue,
      reason:
          "toJson must carry 'remote': fromJson defaults the flag ON "
          'when the key is absent, so a missing producer silently '
          're-enables remote generation on replay',
    );
    expect(json['remote'], isFalse);
  });

  test('bug 1967: generateRemote: false survives toJson -> fromJson', () {
    final config = GeneratorConfig(
      name: 'Product',
      generateRemote: false,
      outputDir: GeneratorConfig.fixedOutputDir,
    );

    final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');
    expect(
      replayed.generateRemote,
      isFalse,
      reason: 'the round-trip must preserve the deliberate opt-out',
    );
  });

  test('bug 1967: default generateRemote: true round-trips as true', () {
    final config = GeneratorConfig(
      name: 'Product',
      outputDir: GeneratorConfig.fixedOutputDir,
    );

    final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');
    expect(replayed.generateRemote, isTrue);
  });

  test('bug 1967: explicit remote:false external JSON still parses false', () {
    final config = GeneratorConfig.fromJson({'remote': false}, 'Product');
    expect(config.generateRemote, isFalse);
  });

  test('bug 1967: custom names survive the round-trip (dedicated keys)', () {
    final config = GeneratorConfig(
      name: 'Product',
      generateRemote: false,
      customPresenterName: 'CustomPresenter',
      customControllerName: 'CustomController',
      outputDir: GeneratorConfig.fixedOutputDir,
    );

    final replayed = GeneratorConfig.fromJson(config.toJson(), 'Product');
    expect(replayed.customPresenterName, 'CustomPresenter');
    expect(replayed.customControllerName, 'CustomController');
    expect(replayed.generateRemote, isFalse);
  });
}
