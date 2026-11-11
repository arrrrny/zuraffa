import 'package:test/test.dart';
import 'package:zuraffa/src/feature_flags/feature_flag.dart';
import 'package:zuraffa/src/feature_flags/feature_flag_config.dart';

/// U1, U2, A4 — feature-flag config parsing, validation, and flavor
/// resolution. Every validation failure must name the offending item.
void main() {
  group('FeatureGate parsing', () {
    test('parses membership gate with tier value', () {
      final gate = FeatureGate.parse('membership:pro');
      expect(gate.type, FeatureGateType.membership);
      expect(gate.value, 'pro');
    });

    test('parses locale gate with comma-separated allow-list', () {
      final gate = FeatureGate.parse('locale:en-US,en-GB');
      expect(gate.type, FeatureGateType.locale);
      expect(gate.values, ['en-US', 'en-GB']);
    });

    test('parses variant gate with pipe-separated variants', () {
      final gate = FeatureGate.parse('variant:a|b');
      expect(gate.type, FeatureGateType.variant);
      expect(gate.values, ['a', 'b']);
    });

    test('parses custom gate with handler name', () {
      final gate = FeatureGate.parse('custom:heavy');
      expect(gate.type, FeatureGateType.custom);
      expect(gate.value, 'heavy');
    });

    test('rejects gate without colon separator', () {
      expect(() => FeatureGate.parse('membership'), throwsFormatException);
    });

    test('rejects gate with empty value', () {
      expect(() => FeatureGate.parse('locale:'), throwsFormatException);
    });

    test(
      '2066: the unknown-type error names platform among the supported kinds',
      () {
        // `platform:` joined the vocabulary, so the parse error must teach it:
        // an error listing the old four sends a typo'd `platforms:macos`
        // hunting for a gate kind that does not exist.
        expect(
          () => FeatureGate.parse('tenant:xyz'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(contains('membership'), contains('platform')),
            ),
          ),
        );
      },
    );

    test('2066: parses platform gate with a single OS value', () {
      final gate = FeatureGate.parse('platform:macos');
      expect(gate.type, FeatureGateType.platform);
      expect(gate.value, 'macos');
      expect(gate.values, ['macos']);
    });

    test('2066: parses platform gate with comma-separated OS allow-list', () {
      final gate = FeatureGate.parse('platform:macos,ios');
      expect(gate.type, FeatureGateType.platform);
      expect(gate.values, ['macos', 'ios']);
    });

    test('2066: rejects platform gate with an empty OS list', () {
      // Same semantics as the locale allow-list: trailing separators are
      // tolerated, a list with nothing usable is malformed.
      expect(() => FeatureGate.parse('platform: , '), throwsFormatException);
      expect(() => FeatureGate.parse('platform:,, '), throwsFormatException);
    });
  });

  group('FeatureFlagConfig parsing (features: section)', () {
    test('parses the list-of-objects shape with gates', () {
      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
          {
            'name': 'beta-scheduler',
            'enabled': false,
            'gates': ['locale:en-US,en-GB'],
          },
        ],
      });
      expect(config.featureNames, hasLength(2));
      expect(config.flag('pro-analytics')!.enabled, isTrue);
      expect(config.flag('beta-scheduler')!.enabled, isFalse);
      expect(
        config.flag('beta-scheduler')!.gates.single.raw,
        'locale:en-US,en-GB',
      );
    });

    test('2066: parses a platform gate through the config layer', () {
      // The config layer accepts `platform:` only because `_parseFlagObject`
      // delegates to FeatureGate.parse — this case locks the end-to-end
      // `.zfa.json` → config → runtime path as the vocabulary grows.
      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {
            'name': 'agent-access',
            'enabled': true,
            'gates': ['platform:macos,ios'],
          },
        ],
      });
      final gate = config.flag('agent-access')!.gates.single;
      expect(gate.type, FeatureGateType.platform);
      expect(gate.values, ['macos', 'ios']);
    });

    test('parses the map shape (name implied by key)', () {
      final config = FeatureFlagConfig.fromJson(const {
        'features': {
          'pro-analytics': {'enabled': true},
        },
      });
      expect(config.featureNames, ['pro-analytics']);
      expect(config.flag('pro-analytics')!.enabled, isTrue);
    });

    test('rejects invalid feature names used as map keys', () {
      expect(
        () => FeatureFlagConfig.fromJson(const {
          'features': {'bad name!': true},
        }),
        throwsA(
          isA<FeatureConfigException>().having(
            (e) => e.message,
            'message',
            contains('bad name!'),
          ),
        ),
      );
    });

    test('rejects an object whose embedded name differs from its map key', () {
      expect(
        () => FeatureFlagConfig.fromJson(const {
          'features': {
            'pro-analytics': {'name': 'notes', 'enabled': true},
          },
        }),
        throwsA(
          isA<FeatureConfigException>().having(
            (e) => e.message,
            'message',
            allOf(contains('pro-analytics'), contains('notes')),
          ),
        ),
      );
    });

    test('empty/missing features section is valid and empty (A1 basis)', () {
      expect(FeatureFlagConfig.fromJson(const {}).featureNames, isEmpty);
      expect(
        FeatureFlagConfig.fromJson(const {'features': []}).featureNames,
        isEmpty,
      );
    });

    test('rejects invalid feature names (must be alphanumeric + hyphen)', () {
      expect(
        () => FeatureFlagConfig.fromJson(const {
          'features': [
            {'name': 'bad name!', 'enabled': true},
          ],
        }),
        throwsA(
          isA<FeatureConfigException>().having(
            (e) => e.message,
            'message',
            contains('bad name!'),
          ),
        ),
      );
    });

    test('rejects duplicate feature names naming the duplicate', () {
      expect(
        () => FeatureFlagConfig.fromJson(const {
          'features': [
            {'name': 'pro-analytics', 'enabled': true},
            {'name': 'pro-analytics', 'enabled': false},
          ],
        }),
        throwsA(
          isA<FeatureConfigException>().having(
            (e) => e.message,
            'message',
            contains('pro-analytics'),
          ),
        ),
      );
    });

    test(
      'rejects unknown gate types naming feature and gate (edge: tenant)',
      () {
        expect(
          () => FeatureFlagConfig.fromJson(const {
            'features': [
              {
                'name': 'beta-scheduler',
                'enabled': true,
                'gates': ['tenant:xyz'],
              },
            ],
          }),
          throwsA(
            isA<FeatureConfigException>().having(
              (e) => e.message,
              'message',
              allOf(contains('beta-scheduler'), contains('tenant:xyz')),
            ),
          ),
        );
      },
    );

    test('rejects invalid gate syntax naming the feature', () {
      expect(
        () => FeatureFlagConfig.fromJson(const {
          'features': [
            {
              'name': 'beta-scheduler',
              'enabled': true,
              'gates': ['locale'],
            },
          ],
        }),
        throwsA(isA<FeatureConfigException>()),
      );
    });
  });

  group('FeatureFlagConfig flavors', () {
    test('parses flavors map of feature overrides', () {
      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
          {'name': 'notes', 'enabled': true},
        ],
        'flavors': {
          'free': {'pro-analytics': false},
        },
      });
      expect(config.flavorNames, ['free']);
      expect(config.flavorOverrides('free')!['pro-analytics'], isFalse);
    });

    test('resolve(flavor) applies overrides over base declarations (U2)', () {
      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
          {'name': 'notes', 'enabled': true},
        ],
        'flavors': {
          'free': {'pro-analytics': false},
          'pro': {},
        },
      });
      final free = config.resolve(flavor: 'free');
      expect(free.isEnabled('pro-analytics'), isFalse);
      expect(free.isEnabled('notes'), isTrue);
      final pro = config.resolve(flavor: 'pro');
      expect(pro.isEnabled('pro-analytics'), isTrue);
    });

    test('resolve(null) uses the base enabled states', () {
      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {'name': 'pro-analytics', 'enabled': true},
          {'name': 'beta-scheduler', 'enabled': false},
        ],
      });
      final resolved = config.resolve();
      expect(resolved.isEnabled('pro-analytics'), isTrue);
      expect(resolved.isEnabled('beta-scheduler'), isFalse);
    });

    test('resolve(unknown flavor) fails naming the flavor', () {
      final config = FeatureFlagConfig.fromJson(const {
        'features': [
          {'name': 'notes', 'enabled': true},
        ],
      });
      expect(
        () => config.resolve(flavor: 'nightly'),
        throwsA(
          isA<FeatureConfigException>().having(
            (e) => e.message,
            'message',
            contains('nightly'),
          ),
        ),
      );
    });

    test(
      'flavor override referencing an undeclared feature fails naming it (A4, US1.AC4)',
      () {
        expect(
          () => FeatureFlagConfig.fromJson(const {
            'features': [
              {'name': 'notes', 'enabled': true},
            ],
            'flavors': {
              'free': {'ghost-feature': false},
            },
          }),
          throwsA(
            isA<FeatureConfigException>().having(
              (e) => e.message,
              'message',
              contains('ghost-feature'),
            ),
          ),
        );
      },
    );
  });
}
