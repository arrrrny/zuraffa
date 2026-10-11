// Spec 1115 — XrayFeatureCapability: the xray capability accepts a TYPED
// FeatureId argument, not a string.
//
// Issue #1115 item 6: the inputSchema for xray becomes
// `feature: { type: 'FeatureId', required: true }` and validates against
// the registered contracts.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/feature/feature_plugin.dart';
import 'package:zuraffa/src/plugins/feature/xray_feature_capability.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_feature_cap_');
    final specDir = Directory(p.join(tempDir.path, 'specs', '004-login-ui'))
      ..createSync(recursive: true);
    File(p.join(specDir.path, 'contract.yaml')).writeAsStringSync('''
id: 004-login-ui
display_name: Login UI
routes:
  - /login
''');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  XrayFeatureCapability capability() =>
      XrayFeatureCapability(FeaturePlugin(outputDir: 'lib/src'));

  group('inputSchema', () {
    test('declares feature as a required FeatureId', () {
      final schema = capability().inputSchema;
      final feature = schema['properties']['feature'] as Map<String, dynamic>;
      expect(feature['type'], 'FeatureId');
      expect(schema['required'], contains('feature'));
    });

    test('the capability is wired into the FeaturePlugin', () {
      expect(
        FeaturePlugin(
          outputDir: 'lib/src',
        ).capabilities.whereType<XrayFeatureCapability>(),
        isNotEmpty,
      );
    });
  });

  group('validateArgs (against the registered contracts)', () {
    test('accepts a registered feature id', () {
      final result = capability().validateArgs({
        'feature': '004-login-ui',
        'projectRoot': tempDir.path,
      });
      expect(result.isValid, isTrue);
      expect(result.featureId?.value, '004-login-ui');
    });

    test('rejects a missing feature (required)', () {
      final result = capability().validateArgs({'projectRoot': tempDir.path});
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('rejects a malformed feature id', () {
      final result = capability().validateArgs({
        'feature': 'not a feature id',
        'projectRoot': tempDir.path,
      });
      expect(result.isValid, isFalse);
    });

    test('rejects an unregistered feature id', () {
      final result = capability().validateArgs({
        'feature': '999-unknown',
        'projectRoot': tempDir.path,
      });
      expect(result.isValid, isFalse);
      expect(result.errors.join(' '), contains('999-unknown'));
    });
  });

  group('execute (the feature-grouped deck scan)', () {
    test('groups the feature-owned files by xray layer', () async {
      File(
          p.join(
            tempDir.path,
            'lib',
            'src',
            'domain',
            'usecases',
            'login_usecase.dart',
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "// @FeatureOwned('004-login-ui')\n// @XrayLayer('engine')\n",
        );
      File(
          p.join(
            tempDir.path,
            'lib',
            'src',
            'presentation',
            'views',
            'login_view.dart',
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "// @FeatureOwned('004-login-ui')\n// @XrayLayer('skin')\n",
        );

      final result = await capability().execute({
        'feature': '004-login-ui',
        'projectRoot': tempDir.path,
      });
      expect(result.success, isTrue);
      final groups = result.data!['features'] as Map<String, dynamic>;
      final feature = groups['004-login-ui'] as Map<String, dynamic>;
      final layers = feature['layers'] as Map<String, dynamic>;
      expect(layers['engine'], 1);
      expect(layers['skin'], 1);
    });
  });
}
