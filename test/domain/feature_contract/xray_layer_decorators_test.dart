// Spec 1115 — the xray_layer decorator (engine | skin | shared).
//
// Issue #1115: the decorator is the PERSISTED cross-layer knowledge —
// `@XrayLayer('engine'|'skin'|'shared')` written by the codegen (and the
// slice composer) as a comment anchor (the @FeatureOwned convention: it
// survives dart format, hand-edits and regeneration), and read back by
// xray scans without compiling the target project.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/xray_layer_decorators.dart';

void main() {
  group('XraySplit', () {
    test('the three split values of the engine-skin split', () {
      expect(XraySplit.values.map((s) => s.name).toSet(), {
        'engine',
        'skin',
        'shared',
      });
    });

    test('parse accepts the issue vocabulary and rejects junk', () {
      expect(XraySplit.parse('engine'), XraySplit.engine);
      expect(XraySplit.parse('skin'), XraySplit.skin);
      expect(XraySplit.parse('shared'), XraySplit.shared);
      expect(() => XraySplit.parse('presentation'), throwsArgumentError);
      expect(() => XraySplit.parse(''), throwsArgumentError);
    });
  });

  group('XrayLayerDecorators', () {
    test('line emits the comment anchor in the issue shape', () {
      expect(
        XrayLayerDecorators.line(XraySplit.engine),
        "// @XrayLayer('engine')",
      );
      expect(XrayLayerDecorators.line(XraySplit.skin), "// @XrayLayer('skin')");
    });

    test('scan reads the anchor back from a source string', () {
      final source = '''
// @XrayLayer('engine')
// @FeatureOwned('004-login-ui')
library;
''';
      expect(XrayLayerDecorators.scan(source), XraySplit.engine);
    });

    test('scan returns null when no anchor is present', () {
      expect(XrayLayerDecorators.scan('void main() {}'), isNull);
    });

    test('forPath maps the clean-architecture trees onto the split', () {
      // engine: domain + data + di wiring
      expect(
        XrayLayerDecorators.forPath(
          'lib/src/domain/usecases/login_usecase.dart',
        ),
        XraySplit.engine,
      );
      expect(
        XrayLayerDecorators.forPath(
          'lib/src/data/datasources/login_remote_datasource.dart',
        ),
        XraySplit.engine,
      );
      // skin: presentation
      expect(
        XrayLayerDecorators.forPath(
          'lib/src/presentation/views/login_view.dart',
        ),
        XraySplit.skin,
      );
      // shared: cross-cutting files (di, core, main)
      expect(
        XrayLayerDecorators.forPath('lib/src/di/login_di.dart'),
        XraySplit.shared,
      );
      expect(XrayLayerDecorators.forPath('lib/main.dart'), XraySplit.shared);
    });

    test('forContractLayer maps the contract deck layer onto the split', () {
      expect(
        XrayLayerDecorators.forContractLayer(XRayLayer.presentation),
        XraySplit.skin,
      );
      expect(
        XrayLayerDecorators.forContractLayer(XRayLayer.domain),
        XraySplit.engine,
      );
      expect(
        XrayLayerDecorators.forContractLayer(XRayLayer.data),
        XraySplit.engine,
      );
    });

    test('stamp is idempotent and prepends both anchors', () {
      const source = 'library;\n\nclass LoginUseCase {}\n';
      final stamped = XrayLayerDecorators.stamp(
        source: source,
        filePath: 'lib/src/domain/usecases/login_usecase.dart',
        featureId: '004-login-ui',
      );
      expect(stamped, contains("// @FeatureOwned('004-login-ui')"));
      expect(stamped, contains("// @XrayLayer('engine')"));
      expect(stamped.startsWith('//'), isTrue);

      // Second stamp does not duplicate the anchors.
      final restamped = XrayLayerDecorators.stamp(
        source: stamped,
        filePath: 'lib/src/domain/usecases/login_usecase.dart',
        featureId: '004-login-ui',
      );
      expect(restamped, stamped);
      expect('@XrayLayer'.allMatches(restamped).length, 1);
    });

    test('stamp keeps an existing layer anchor as-is', () {
      const source = "// @XrayLayer('skin')\nlibrary;\n";
      final stamped = XrayLayerDecorators.stamp(
        source: source,
        filePath: 'lib/src/domain/usecases/login_usecase.dart',
        featureId: '004-login-ui',
      );
      expect(XrayLayerDecorators.scan(stamped), XraySplit.skin);
    });

    test('scanRoot groups a project tree by the decorated split', () {
      final tempDir = Directory.systemTemp.createTempSync('xray_layer_scan_');
      try {
        File(p.join(tempDir.path, 'lib', 'src', 'domain', 'usecases', 'a.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync("// @XrayLayer('engine')\nlibrary;\n");
        File(
            p.join(
              tempDir.path,
              'lib',
              'src',
              'presentation',
              'views',
              'b.dart',
            ),
          )
          ..createSync(recursive: true)
          ..writeAsStringSync("// @XrayLayer('skin')\nlibrary;\n");
        File(p.join(tempDir.path, 'lib', 'main.dart'))
          ..createSync(recursive: true)
          ..writeAsStringSync('void main() {}\n');

        final grouped = XrayLayerDecorators.scanRoot(tempDir.path);
        expect(grouped[XraySplit.engine], isNotNull);
        expect(grouped[XraySplit.skin], isNotNull);
        // main.dart has no anchor → not grouped.
        expect(
          grouped.values.expand((s) => s).where((f) => f.endsWith('main.dart')),
          isEmpty,
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
