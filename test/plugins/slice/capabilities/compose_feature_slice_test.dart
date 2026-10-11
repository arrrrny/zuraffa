// Spec 1114 — typed, worktree-scoped, contract-checked `slice compose`.
//
// #1114 (the slice half of the ENGINE-SKIN-SPLIT pilot evidence): compose
// resolves the feature contract (specs/<id>/contract.yaml, or the spec's
// `## Skin Contract` JSON, or its `## Lanes` CORE block) — NOT a raw
// string — and writes `.zfa/slices/<feature-id>/` containing engine/
// skin/ contract/ receipts/: the minimal base an agent receives for that
// feature, and only that feature.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/compose_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/models/feature_slice_manifest.dart';
import 'package:zuraffa/src/plugins/slice/services/feature_contract_resolution.dart';

import '../helpers/feature_slice_fixture.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp(
      'zfa_slice_compose_1114_',
    );
    buildLoginProbe(workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  String slicePath(String rel) =>
      p.join(workspace.path, '.zfa', 'slices', 'login', rel);

  group('ComposeSliceCapability (spec 1114: typed compose)', () {
    test(
      'writes .zfa/slices/login/ with engine/ skin/ contract/ receipts/',
      () async {
        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isTrue, reason: result.message);
        expect(result.sliceRoot, isNotNull);
        for (final dir in ['engine', 'skin', 'contract', 'receipts']) {
          expect(
            Directory(slicePath(dir)).existsSync(),
            isTrue,
            reason: 'slice must contain $dir/',
          );
        }
        expect(File(slicePath('slice.yaml')).existsSync(), isTrue);
      },
    );

    test("engine/ has ONLY the contract's entities (scoping proof)", () async {
      await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      // Owned engine files copied into the slice.
      expect(
        File(slicePath('engine/entities/User/user.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('engine/entities/Session/session.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(
          slicePath('engine/repositories/user_repository.dart'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('engine/usecases/login_user.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('engine/services/user_service.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(
          slicePath('engine/datasources/user_remote_datasource.dart'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('engine/mocks/mock_user_datasource.dart')).existsSync(),
        isTrue,
      );
      expect(File(slicePath('engine/di/user_di.dart')).existsSync(), isTrue);

      // NOT owned: the agent never sees them.
      expect(
        Directory(slicePath('engine/entities/Other')).existsSync(),
        isFalse,
        reason: 'entities outside the contract must not enter the slice',
      );
      expect(
        File(slicePath('engine/usecases/other_usecase.dart')).existsSync(),
        isFalse,
        reason: 'usecases outside the contract must not enter the slice',
      );
    });

    test("skin/ has ONLY the contract's routes (scoping proof)", () async {
      await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      expect(
        File(slicePath('skin/views/login_view.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('skin/views/login_forgot_view.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('skin/widgets/login_button.dart')).existsSync(),
        isTrue,
      );
      expect(
        File(slicePath('skin/states/login_state.dart')).existsSync(),
        isTrue,
      );

      expect(
        File(slicePath('skin/views/other_view.dart')).existsSync(),
        isFalse,
        reason: 'views outside the contract routes must not enter the slice',
      );

      // The generated routes barrel exposes EXACTLY the contract routes.
      final router = File(slicePath('skin/routes/router.dart'));
      expect(router.existsSync(), isTrue);
      final routerSrc = router.readAsStringSync();
      expect(routerSrc, contains('/login'));
      expect(routerSrc, contains('/login/forgot'));
      expect(routerSrc, contains("'/login': 'LoginView'"));
      expect(routerSrc, isNot(contains('/other')));
    });

    test(
      'contract/ carries the contract JSON; receipts/ carries the spec tree',
      () async {
        await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        final contractJson =
            jsonDecode(
                  File(slicePath('contract/contract.json')).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(contractJson['id'], 'login');
        expect(contractJson['display_name'], 'Login');
        expect(contractJson['entities'], ['User', 'Session']);
        expect(
          contractJson['routes'],
          containsAll(['/login', '/login/forgot']),
        );
        expect(contractJson['xray_layer'], 'presentation');

        expect(File(slicePath('receipts/spec.md')).existsSync(), isTrue);
        expect(File(slicePath('receipts/contract.yaml')).existsSync(), isTrue);
        expect(
          File(slicePath('receipts/tdd/test-list.md')).existsSync(),
          isTrue,
          reason: 'the tdd receipts travel with the slice',
        );
      },
    );

    test(
      'the tdd mount specs/login/ lets zfa tdd run inside the slice',
      () async {
        await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(
          File(slicePath('specs/login/tdd/test-list.md')).existsSync(),
          isTrue,
          reason: 'the worktree needs specs/<feature>/tdd to run the cycles',
        );
      },
    );

    test(
      'slice.yaml is feature-centric: manifest.feature = FeatureContract',
      () async {
        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        final manifest = result.manifest;
        expect(manifest, isNotNull);
        expect(manifest!.feature.id, 'login');
        expect(manifest.feature.entities, ['User', 'Session']);
        expect(manifest.feature.routes, contains('/login'));
        expect(manifest.feature.xrayLayer, XRayLayer.presentation);
        expect(manifest.engineEntities.keys, containsAll(['User', 'Session']));
        expect(manifest.engineEntities['User'], isNotEmpty);
        expect(
          manifest.engineFiles
              .map((f) => f.entity)
              .every((e) => manifest.feature.entities!.contains(e!)),
          isTrue,
        );
        expect(
          manifest.skinFiles
              .map((f) => f.route)
              .every((r) => manifest.feature.routes!.contains(r!)),
          isTrue,
        );
        // Specific-route attribution: a multi-segment route owns its
        // specific view — the prefix route must not claim it (mutation
        // hardening for the routes-by-specificity ordering).
        final forgotView = manifest.skinFiles.firstWhere(
          (f) => f.relativePath == 'skin/views/login_forgot_view.dart',
        );
        expect(forgotView.route, '/login/forgot');
        expect(
          manifest.skinRoutes.firstWhere((r) => r.path == '/login/forgot').view,
          'LoginForgotView',
        );

        // The persisted slice.yaml round-trips the feature axis.
        final reread = FeatureSliceManifest.fromYaml(
          File(slicePath('slice.yaml')).readAsStringSync(),
        );
        expect(reread.feature.id, 'login');
        expect(reread.engineEntities['User'], isNotEmpty);
      },
    );

    test(
      'deterministic: re-compose writes byte-identical content (FR-007)',
      () async {
        await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        final first = File(
          slicePath('contract/contract.json'),
        ).readAsStringSync();
        final firstRouter = File(
          slicePath('skin/routes/router.dart'),
        ).readAsStringSync();

        await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        expect(
          File(slicePath('contract/contract.json')).readAsStringSync(),
          first,
        );
        expect(
          File(slicePath('skin/routes/router.dart')).readAsStringSync(),
          firstRouter,
        );
      },
    );

    test(
      're-compose excludes its generated plan from receipts and mount',
      () async {
        await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        final second = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(second.success, isTrue, reason: second.message);
        expect(
          second.manifest!.receiptsFiles,
          isNot(contains('receipts/compose.plan.json')),
        );
        expect(
          File(slicePath('receipts/compose.plan.json')).existsSync(),
          isFalse,
        );
        expect(
          File(slicePath('specs/login/compose.plan.json')).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'nested engine and skin files preserve source-relative subpaths',
      () async {
        writeFile(
          workspace.path,
          'lib/src/domain/usecases/admin/user_lookup.dart',
          'class AdminUserLookup {}\n',
        );
        writeFile(
          workspace.path,
          'lib/src/domain/usecases/member/user_lookup.dart',
          'class MemberUserLookup {}\n',
        );
        writeFile(
          workspace.path,
          'lib/src/presentation/views/mobile/login_view.dart',
          'class MobileLoginView {}\n',
        );
        writeFile(
          workspace.path,
          'lib/src/presentation/views/desktop/login_view.dart',
          'class DesktopLoginView {}\n',
        );

        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isTrue, reason: result.message);
        for (final rel in [
          'engine/usecases/admin/user_lookup.dart',
          'engine/usecases/member/user_lookup.dart',
          'skin/views/mobile/login_view.dart',
          'skin/views/desktop/login_view.dart',
        ]) {
          expect(File(slicePath(rel)).existsSync(), isTrue, reason: rel);
        }
      },
    );

    test(
      'active worktree slices require an explicit force to re-compose',
      () async {
        final first = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        final manifestFile = File(slicePath('slice.yaml'));
        manifestFile.writeAsStringSync(
          first.manifest!.copyWith(worktreePath: '.zfa/slices/login').toYaml(),
        );
        final sentinel = File(slicePath('agent-work.txt'))
          ..writeAsStringSync('keep');

        final refused = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        expect(refused.success, isFalse);
        expect(refused.message, contains('active worktree'));
        expect(sentinel.existsSync(), isTrue);

        final forced = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
          force: true,
        );
        expect(forced.success, isTrue, reason: forced.message);
        expect(sentinel.existsSync(), isFalse);
      },
    );

    test(
      'resolves the contract from the spec.md ## Skin Contract (fallback)',
      () async {
        // No contract.yaml — the spec's Skin Contract JSON declares the skin.
        final specDir = Directory(p.join(workspace.path, 'specs', 'login'));
        for (final entity in specDir.listSync()) {
          if (entity is File && p.basename(entity.path) == 'contract.yaml') {
            entity.deleteSync();
          }
        }
        File(p.join(specDir.path, 'spec.md')).writeAsStringSync('''
# Login

## Skin Contract: login

```json
{
  "schemaVersion": "1",
  "routes": [
    {"path": "/login", "view": "LoginView"}
  ],
  "states": [
    {"view": "LoginView", "loading": true, "error": "inline", "empty": false}
  ],
  "platformRows": [],
  "stateRows": []
}
```
''');

        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isTrue, reason: result.message);
        expect(result.contract!.routes, contains('/login'));
        expect(result.contract!.xrayLayer, XRayLayer.presentation);
        expect(result.manifest!.origin, 'spec.md:skin-contract');

        final contractJson =
            jsonDecode(
                  File(slicePath('contract/contract.json')).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(contractJson['routes'], ['/login']);
      },
    );

    test(
      'resolves the contract from the ## Lanes CORE block (engine-only)',
      () async {
        final specDir = Directory(p.join(workspace.path, 'specs', 'login'));
        for (final entity in specDir.listSync()) {
          if (entity is File && p.basename(entity.path) == 'contract.yaml') {
            entity.deleteSync();
          }
        }
        File(p.join(specDir.path, 'spec.md')).writeAsStringSync('''
# Engine-only

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1, U2]
    flutter_allowed: false
```
''');

        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isTrue, reason: result.message);
        expect(result.contract!.xrayLayer, XRayLayer.domain);
        expect(result.manifest!.origin, 'spec.md:lanes-core');
        // Engine-only: no declared routes, no views enter the slice.
        expect(
          Directory(slicePath('skin/views')).existsSync(),
          isFalse,
          reason: 'no contract routes => no views composed',
        );
      },
    );

    test('an unknown feature id fails with the known ids listed', () async {
      final result = await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'checkout',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('checkout'));
      expect(result.message, contains('login'));
    });

    test(
      'the typed contract from the context is used, not the raw string (1114 #5)',
      () async {
        // A workspace with NO specs/ tree at all: the only contract in
        // play is the typed object passed in (the PluginContext carrier).
        final bareRoot = await Directory.systemTemp.createTemp('zfa_bare_');
        addTearDown(() async {
          if (bareRoot.existsSync()) await bareRoot.delete(recursive: true);
        });

        final typed = FeatureContract(
          id: 'login',
          displayName: 'Login',
          entities: ['User'],
          routes: {'/login'},
          xrayLayer: XRayLayer.presentation,
        );

        final result = await ComposeSliceCapability().execute(
          projectRoot: bareRoot.path,
          featureId: 'login',
          contract: typed,
        );

        expect(result.success, isTrue, reason: result.message);
        expect(result.contract!.id, 'login');
        final manifest = FeatureSliceManifest.fromYaml(
          File(
            p.join(bareRoot.path, '.zfa', 'slices', 'login', 'slice.yaml'),
          ).readAsStringSync(),
        );
        expect(manifest.feature.id, 'login');
      },
    );
  });

  group('resolveFeatureContract (spec 1114 resolution order)', () {
    test('specs/<id>/contract.yaml wins when present', () {
      final resolved = resolveFeatureContract(
        projectRoot: workspace.path,
        featureId: 'login',
      );
      expect(resolved, isNotNull);
      expect(resolved!.origin, 'contract.yaml');
      expect(resolved.contract.entities, ['User', 'Session']);
    });

    test('an unknown feature id resolves to null (no guessing)', () {
      expect(
        resolveFeatureContract(projectRoot: workspace.path, featureId: 'nope'),
        isNull,
      );
    });
  });
}
