/// Tests for ManifestBuilder (U9-U12, U33).
///
/// Behaviors traced to test-list.md:
///   U9: renders schema-valid YAML with version, feature, spec_version,
///       entities, layers
///   U10: renders dependencies: [] when the bone has no dependencies
///   U11: renders a dependency entry with bone slug and shared entity names
///   U12: the rendered spec_version matches sha256: + 64 lowercase hex chars
///   U33: xray overlay markers are rendered under an xray: key
///
/// Pure-Dart: no I/O, no network, deterministic.
library;

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/plugins/skeleton/builders/manifest_builder.dart';
import 'package:zuraffa/src/plugins/skeleton/models/bone.dart';

void main() {
  late ManifestBuilder builder;

  setUp(() {
    builder = ManifestBuilder();
  });

  BoneManifest makeManifest({
    List<String> entities = const ['Product'],
    List<BoneDependency> dependencies = const [],
    String? specVersion,
    Map<String, String> xray = const {},
    DiChoice? diChoice,
    bool flutter = false,
  }) {
    return BoneManifest(
      version: 1,
      feature: 'test-feature',
      generatedAt: '2026-08-29T12:00:00.000Z',
      specVersion: specVersion ?? 'sha256:${'a' * 64}',
      entities: entities,
      dependencies: dependencies,
      layers: const ['domain', 'data', 'presentation'],
      xray: xray,
      diChoice: diChoice,
      flutter: flutter,
    );
  }

  group('ManifestBuilder.render', () {
    test(
      'U9: renders schema-valid YAML with version, feature, spec_version, entities, layers',
      () {
        final yaml = builder.render(
          makeManifest(entities: ['Cart', 'CartItem']),
        );
        final parsed = loadYaml(yaml) as Map;

        expect(parsed['version'], equals(1));
        expect(parsed['feature'], equals('test-feature'));
        expect(parsed['spec_version'], startsWith('sha256:'));
        expect(parsed['entities'], equals(['Cart', 'CartItem']));
        expect(parsed['layers'], equals(['domain', 'data', 'presentation']));
      },
    );

    test('U10: renders dependencies: [] when the bone has no dependencies', () {
      final yaml = builder.render(makeManifest());
      final parsed = loadYaml(yaml) as Map;

      expect(parsed['dependencies'], isEmpty);
    });

    test(
      'U11: renders a dependency entry with bone slug and shared entity names',
      () {
        final manifest = makeManifest(
          dependencies: [
            const BoneDependency(
              bone: 'product-catalog',
              entities: ['Product'],
            ),
          ],
        );
        final yaml = builder.render(manifest);
        final parsed = loadYaml(yaml) as Map;

        final deps = parsed['dependencies'] as List;
        expect(deps, hasLength(1));
        expect(deps[0]['bone'], equals('product-catalog'));
        expect(deps[0]['entities'], equals(['Product']));
      },
    );

    test(
      'U12: the rendered spec_version matches sha256: + 64 lowercase hex chars',
      () {
        final manifest = makeManifest(
          specVersion:
              'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        );
        final yaml = builder.render(manifest);
        final parsed = loadYaml(yaml) as Map;

        final sv = parsed['spec_version'] as String;
        expect(sv, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
      },
    );

    test('U33: xray overlay markers are rendered under an xray: key', () {
      final manifest = makeManifest(
        xray: {
          'overlay': '{"enabled": true, "color": "neon-green"}',
          'mode': 'development',
        },
      );
      final yaml = builder.render(manifest);
      final parsed = loadYaml(yaml) as Map;

      expect(
        parsed.containsKey('xray'),
        isTrue,
        reason: 'xray key must be present',
      );
      final xray = parsed['xray'] as Map;
      expect(
        xray['overlay'],
        equals('{"enabled": true, "color": "neon-green"}'),
      );
      expect(xray['mode'], equals('development'));
    });

    test('U33: manifest without xray markers omits the xray key', () {
      final yaml = builder.render(makeManifest());
      final parsed = loadYaml(yaml) as Map;

      expect(
        parsed.containsKey('xray'),
        isFalse,
        reason: 'xray key must not be present when there are no markers',
      );
    });
  });

  group('ManifestBuilder.render (042 working slice)', () {
    test('042-U32: renders di + di_source keys from the DI choice', () {
      final yaml = builder.render(
        makeManifest(diChoice: DiChoice.auto().resolve(detectedBackend: null)),
      );
      final parsed = loadYaml(yaml) as Map;

      expect(parsed['di'], equals('mock'));
      expect(parsed['di_source'], equals('auto-fallback'));
    });

    test('042-U32: flag choice renders flag source', () {
      final yaml = builder.render(
        makeManifest(diChoice: DiChoice.fromFlag('firebase').resolve()),
      );
      final parsed = loadYaml(yaml) as Map;

      expect(parsed['di'], equals('firebase'));
      expect(parsed['di_source'], equals('flag'));
    });

    test('042-U33: flutter mode renders flutter + entrypoint keys; '
        'library mode omits them', () {
      final flutterYaml = builder.render(
        makeManifest(
          diChoice: DiChoice.fromFlag('mock').resolve(),
          flutter: true,
        ),
      );
      final flutterParsed = loadYaml(flutterYaml) as Map;
      expect(flutterParsed['flutter'], isTrue);
      expect(flutterParsed['entrypoint'], equals('lib/main.dart'));

      final libraryYaml = builder.render(
        makeManifest(diChoice: DiChoice.fromFlag('mock').resolve()),
      );
      final libraryParsed = loadYaml(libraryYaml) as Map;
      expect(libraryParsed.containsKey('flutter'), isFalse);
      expect(libraryParsed.containsKey('entrypoint'), isFalse);
    });

    test('042: existing keys keep their meaning when di is present', () {
      final yaml = builder.render(
        makeManifest(
          entities: ['User'],
          dependencies: const [
            BoneDependency(bone: 'feature-a', entities: ['Product']),
          ],
          diChoice: DiChoice.fromFlag('mock').resolve(),
        ),
      );
      final parsed = loadYaml(yaml) as Map;

      expect(parsed['version'], equals(1));
      expect(parsed['feature'], equals('test-feature'));
      expect(parsed['entities'], equals(['User']));
      final deps = parsed['dependencies'] as List;
      expect(deps.first['bone'], equals('feature-a'));
    });
  });
}
