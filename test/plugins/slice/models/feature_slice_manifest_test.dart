// Spec 1114 — FeatureSliceManifest (feature-centric manifest) tests.
//
// The 043 manifest groups files by entity with the feature as the outer
// path key; after 1114 the FEATURE is the primary axis:
// manifest.feature = <FeatureContract>, entities/routes/layers are
// children of the feature. These tests pin the model + YAML round-trip.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/plugins/slice/models/feature_slice_manifest.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_boundary.dart';

void main() {
  FeatureContract contract() => FeatureContract(
    id: 'login',
    displayName: 'Login',
    entities: ['User', 'Session'],
    routes: {'/login', '/login/forgot'},
    xrayLayer: XRayLayer.presentation,
    boundary: SliceBoundary(
      typeName: 'LoginRepository',
      interfaceFile: 'lib/src/domain/repositories/user_repository.dart',
      mockStrategy: 'auto',
    ),
  );

  FeatureSliceManifest manifest() => FeatureSliceManifest(
    createdAt: DateTime.parse('2026-09-06T00:00:00Z'),
    feature: contract(),
    origin: 'contract.yaml',
    projectRoot: '/probe',
    parentBranch: 'master',
    parentHead: 'abc1234',
    sliceRoot: '.zfa/slices/login',
    engineFiles: [
      FeatureSliceFile(
        relativePath: 'engine/entities/user/user.dart',
        layer: 'domain',
        entity: 'User',
        hashAtCut: 'h1',
      ),
      FeatureSliceFile(
        relativePath: 'engine/mocks/mock_user_datasource.dart',
        layer: 'data',
        entity: 'User',
        hashAtCut: 'h2',
      ),
    ],
    engineEntities: {
      'User': ['engine/entities/user/user.dart'],
      'Session': const [],
    },
    skinFiles: [
      FeatureSliceFile(
        relativePath: 'skin/views/login_view.dart',
        layer: 'presentation',
        route: '/login',
        hashAtCut: 'h3',
      ),
    ],
    skinRoutes: [
      FeatureSkinRoute(path: '/login', view: 'LoginView'),
      FeatureSkinRoute(path: '/login/forgot', view: 'LoginForgotView'),
    ],
    contractFile: 'contract/contract.json',
    contractDigest: 'deadbeef',
    receiptsFiles: ['receipts/spec.md'],
    generatedFiles: ['skin/routes/router.dart'],
    worktreePath: '.zfa/slices/login',
    worktreeBranch: 'slice/login',
    worktreeCommit: 'def5678',
  );

  group('FeatureSliceManifest (spec 1114: feature-centric axis)', () {
    test('manifest.feature IS the FeatureContract — primary axis', () {
      final m = manifest();
      expect(m.feature.id, 'login');
      expect(m.feature.entities, ['User', 'Session']);
      expect(m.feature.routes, {'/login', '/login/forgot'});
      expect(m.feature.xrayLayer, XRayLayer.presentation);
      expect(m.schema, 'slice.manifest.v2');
    });

    test('entities/routes/layers are children of the feature', () {
      final m = manifest();
      expect(m.engineEntities.keys, containsAll(['User', 'Session']));
      expect(m.skinRoutes.map((r) => r.path), contains('/login/forgot'));
      // engine + skin files are children grouped under the feature axis:
      expect(
        m.engineFiles
            .map((f) => f.entity)
            .every((e) => m.feature.entities!.contains(e)),
        isTrue,
      );
      expect(
        m.skinFiles
            .map((f) => f.route)
            .every((r) => m.feature.routes!.contains(r)),
        isTrue,
      );
    });

    test('toYaml emits the feature as the primary section', () {
      final yaml = manifest().toYaml();
      // The feature block comes before engine/skin/contract/receipts —
      // feature-first, entity-nested.
      final featureAt = yaml.indexOf('feature:\n  id: "login"');
      final engineAt = yaml.indexOf('engine:');
      final skinAt = yaml.indexOf('skin:');
      expect(featureAt, greaterThanOrEqualTo(0));
      expect(engineAt, greaterThan(featureAt));
      expect(skinAt, greaterThan(featureAt));
      expect(yaml, contains('entities:'));
      expect(yaml, contains('- "User"'));
      expect(yaml, contains('- "/login/forgot"'));
    });

    test('YAML round-trip: fromYaml(toYaml(m)) == m (feature axis intact)', () {
      final m = manifest();
      final back = FeatureSliceManifest.fromYaml(m.toYaml());

      expect(back.schema, m.schema);
      expect(back.createdAt, m.createdAt);
      expect(back.feature.id, 'login');
      expect(back.feature.displayName, 'Login');
      expect(back.feature.entities, ['User', 'Session']);
      expect(back.feature.routes, {'/login', '/login/forgot'});
      expect(back.feature.xrayLayer, XRayLayer.presentation);
      expect(back.feature.boundary?.typeName, 'LoginRepository');
      expect(back.origin, 'contract.yaml');
      expect(back.projectRoot, '/probe');
      expect(back.parentBranch, 'master');
      expect(back.parentHead, 'abc1234');
      expect(back.sliceRoot, '.zfa/slices/login');
      expect(back.engineFiles.length, 2);
      expect(
        back.engineFiles.first.relativePath,
        'engine/entities/user/user.dart',
      );
      expect(back.engineFiles.first.entity, 'User');
      expect(back.engineFiles.first.layer, 'domain');
      expect(back.engineFiles.first.hashAtCut, 'h1');
      expect(back.engineEntities['User'], ['engine/entities/user/user.dart']);
      expect(back.skinFiles.first.route, '/login');
      expect(back.skinRoutes.length, 2);
      expect(back.skinRoutes.last.view, 'LoginForgotView');
      expect(back.contractFile, 'contract/contract.json');
      expect(back.contractDigest, 'deadbeef');
      expect(back.receiptsFiles, ['receipts/spec.md']);
      expect(back.generatedFiles, ['skin/routes/router.dart']);
      expect(back.worktreePath, '.zfa/slices/login');
      expect(back.worktreeBranch, 'slice/login');
      expect(back.worktreeCommit, 'def5678');
    });

    test('copyWith replaces the feature axis', () {
      final m = manifest().copyWith(
        worktreePath: null,
        worktreeBranch: null,
        worktreeCommit: null,
      );
      expect(m.worktreePath, isNull);
      expect(m.feature.id, 'login');
    });

    test('fromYaml rejects corrupt documents with a typed error', () {
      expect(
        () => FeatureSliceManifest.fromYaml('not: [a map'),
        throwsA(isA<FeatureSliceManifestYamlError>()),
      );
      expect(
        () => FeatureSliceManifest.fromYaml('schema: slice.manifest.v2\n'),
        throwsA(isA<FeatureSliceManifestYamlError>()),
      );
    });

    test('all emitted string values with YAML syntax round-trip', () {
      final special = FeatureSliceManifest(
        createdAt: DateTime.parse('2026-09-06T00:00:00Z'),
        feature: FeatureContract(
          id: '# login',
          displayName: 'Login: "quoted"',
          entities: ["- User's"],
          routes: {'/{login}: #value'},
          xrayLayer: XRayLayer.presentation,
          boundary: SliceBoundary(
            typeName: 'Login:Repository',
            interfaceFile: 'lib/#special:repo.dart',
            diRegistrationFile: '- di.dart',
            mockStrategy: '{auto}',
          ),
        ),
        origin: 'spec.md: #skin',
        projectRoot: '/tmp/root: #one',
        parentBranch: '- branch',
        parentHead: 'yes',
        sliceRoot: '.zfa/slices/# login',
        engineFiles: [
          FeatureSliceFile(
            relativePath: 'engine/a: #b.dart',
            layer: 'domain:core',
            entity: "- User's",
            hashAtCut: '#digest',
          ),
        ],
        engineEntities: {
          "- User's": ['engine/a: #b.dart'],
        },
        skinFiles: [
          FeatureSliceFile(
            relativePath: 'skin/{view}.dart',
            layer: 'presentation #1',
            route: '/{login}: #value',
            hashAtCut: 'digest:two',
          ),
        ],
        skinRoutes: [
          FeatureSkinRoute(path: '/{login}: #value', view: 'Login:View'),
        ],
        contractFile: 'contract/#contract.json',
        contractDigest: 'digest: #three',
        receiptsFiles: ['receipts/- spec.md'],
        generatedFiles: ['skin/routes/#router.dart'],
        worktreePath: '.zfa/slices/# login',
        worktreeBranch: '- slice/login',
        worktreeCommit: '#commit',
      );

      final back = FeatureSliceManifest.fromYaml(special.toYaml());

      expect(back.feature.id, special.feature.id);
      expect(back.feature.displayName, special.feature.displayName);
      expect(back.feature.entities, special.feature.entities);
      expect(back.feature.routes, special.feature.routes);
      expect(
        back.feature.boundary?.interfaceFile,
        special.feature.boundary?.interfaceFile,
      );
      expect(back.origin, special.origin);
      expect(back.projectRoot, special.projectRoot);
      expect(back.parentBranch, special.parentBranch);
      expect(
        back.engineFiles.first.relativePath,
        special.engineFiles.first.relativePath,
      );
      expect(back.engineEntities, special.engineEntities);
      expect(back.skinRoutes.first.view, special.skinRoutes.first.view);
      expect(back.contractDigest, special.contractDigest);
      expect(back.receiptsFiles, special.receiptsFiles);
      expect(back.worktreeCommit, special.worktreeCommit);
    });

    test('fromYaml wraps invalid scalar values in the typed error', () {
      final valid = manifest().toYaml();
      final invalidDocuments = [
        valid.replaceFirst('schema: "slice.manifest.v2"', 'schema: 2'),
        valid.replaceFirst(
          'createdAt: "2026-09-06T00:00:00.000Z"',
          'createdAt: "not-a-time"',
        ),
        valid.replaceFirst('xray_layer: "presentation"', 'xray_layer: "bogus"'),
        valid.replaceFirst('contract:\n  file:', 'contract: invalid\nignored:'),
        valid.replaceFirst('type_name: "LoginRepository"', 'type_name: []'),
      ];

      for (final source in invalidDocuments) {
        expect(
          () => FeatureSliceManifest.fromYaml(source),
          throwsA(isA<FeatureSliceManifestYamlError>()),
        );
      }
    });
  });
}
