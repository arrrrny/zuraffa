// Spec 1115 — THE feature-grouping proof (issue #1115 success criteria).
//
// Proves, end to end on a sandbox project:
//   1. XRayNode.featureId is TYPED (FeatureId) and nodes group by it.
//   2. The slice composer stamps @XrayLayer('engine') on engine/ files and
//      @XrayLayer('skin') on skin/ files (the persisted cross-layer
//      knowledge, written by the codegen).
//   3. `zfa xray deck --feature=004-login-ui` groups the feature's nodes
//      by feature and prints the layer breakdown.
//   4. `zfa xray check 004-login-ui` exits 0 on a clean slice and exits 1
//      with named violators otherwise.
//
// Hermetic: the sandbox root is passed via `--root` (never chdir).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_id.dart';
import 'package:zuraffa/src/plugins/slice/generators/feature_slice_composer.dart';
import 'package:zuraffa/src/plugins/xray/xray_node.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';
import 'package:zuraffa/src/zfa_cli.dart';

const featureId = '004-login-ui';

void main() {
  late Directory tempDir;
  late FeatureContract contract;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_feature_group_');
    contract = _scaffoldProject(tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('XRayNode.featureId is typed and groups by feature (criterion 1)', () {
    test('featureId is a FeatureId, not a raw string', () {
      final node = XRayNode(
        id: 'LoginViewNode.loginButton',
        viewType: 'LoginView',
        enabled: true,
        stateSummary: const XRayStateSummary(
          hasData: false,
          hasError: false,
          isLoading: false,
        ),
        featureId: FeatureId.parse(featureId),
      );
      expect(node.featureId, isA<FeatureId>());
      expect(node.featureId, FeatureId.parse(featureId));
    });

    test('nodes group by featureId — one map key per feature', () {
      XRayNode nodeFor(FeatureId? feature) => XRayNode(
        id: 'LoginViewNode.loginButton',
        viewType: 'LoginView',
        enabled: true,
        stateSummary: const XRayStateSummary(
          hasData: false,
          hasError: false,
          isLoading: false,
        ),
        featureId: feature,
      );

      final nodes = [
        nodeFor(FeatureId.parse(featureId)),
        nodeFor(FeatureId.parse('004-login-ui')),
        nodeFor(FeatureId.parse('005-settings')),
        nodeFor(null),
      ];

      final byFeature = <FeatureId?, List<XRayNode>>{};
      for (final node in nodes) {
        (byFeature[node.featureId] ??= []).add(node);
      }
      expect(byFeature.keys.length, 3);
      expect(byFeature[FeatureId.parse(featureId)]!.length, 2);
      expect(byFeature[FeatureId.parse('005-settings')]!.length, 1);
      expect(byFeature[null]!.length, 1);
    });

    test('JSON round-trip stays typed', () {
      final node = XRayNode(
        id: 'LoginViewNode.loginButton',
        viewType: 'LoginView',
        enabled: true,
        stateSummary: const XRayStateSummary(
          hasData: false,
          hasError: false,
          isLoading: false,
        ),
        featureId: FeatureId.parse(featureId),
      );
      final restored = XRayNode.fromJson(node.toJson());
      expect(restored.featureId, FeatureId.parse(featureId));
      expect(restored.toJson()['featureId'], featureId);
    });
  });

  group('the composer writes the xray_layer decorator (criterion 2)', () {
    test(
      'engine/ files carry @XrayLayer(engine), skin/ files @XrayLayer(skin)',
      () {
        final sliceRoot = FeatureSliceComposer.sliceRootOf(
          tempDir.path,
          featureId,
        );
        final composition = FeatureSliceComposer().compose(
          projectRoot: tempDir.path,
          contract: contract,
          origin: 'contract.yaml',
        );

        final usecaseFile = File(
          p.join(sliceRoot, 'engine', 'usecases', 'login_usecase.dart'),
        );
        expect(usecaseFile.existsSync(), isTrue);
        expect(
          usecaseFile.readAsStringSync(),
          contains("// @XrayLayer('engine')"),
          reason: 'an engine/ file in the slice carries @XrayLayer(engine)',
        );
        expect(
          usecaseFile.readAsStringSync(),
          contains("// @FeatureOwned('$featureId')"),
        );

        final viewFile = File(
          p.join(sliceRoot, 'skin', 'views', 'login_view.dart'),
        );
        expect(viewFile.existsSync(), isTrue);
        expect(
          viewFile.readAsStringSync(),
          contains("// @XrayLayer('skin')"),
          reason: 'a skin/ view in the slice carries @XrayLayer(skin)',
        );

        // The generated router is skin knowledge too.
        expect(
          File(
            p.join(sliceRoot, 'skin', 'routes', 'router.dart'),
          ).readAsStringSync(),
          contains("// @XrayLayer('skin')"),
        );

        // The manifest's hashAtCut describes the STAMPED slice file.
        final manifest = composition.manifest;
        final usecaseEntry = manifest.engineFiles.firstWhere(
          (f) => f.relativePath == 'engine/usecases/login_usecase.dart',
        );
        expect(usecaseEntry.hashAtCut, isNotEmpty);
      },
    );
  });

  group('zfa xray deck --feature groups by feature (criterion 3)', () {
    test(
      'prints the feature-grouped layer breakdown and stamps the deck',
      () async {
        FeatureSliceComposer().compose(
          projectRoot: tempDir.path,
          contract: contract,
          origin: 'contract.yaml',
        );

        final yamlFile = File(p.join(tempDir.path, 'login_mocks.yaml'))
          ..writeAsStringSync(
            '- name: Valid\n  payload: "123"\n  type: valid\n',
          );
        final output = p.join(tempDir.path, 'login_xray_deck.dart');

        final log = await runCapturing([
          'xray',
          'deck',
          '--root=${tempDir.path}',
          '--yaml=${yamlFile.path}',
          '--output=$output',
          '--usecase-name=Login',
          '--feature=$featureId',
          '--force',
        ]);

        // The deck answers "what code is in which layer for which feature".
        expect(log, contains(featureId));
        expect(log, contains('Layer breakdown'));
        expect(log, contains('engine'));
        expect(log, contains('skin'));

        // The deck artifact itself is stamped with the contract-mapped layer.
        final deckSource = File(output).readAsStringSync();
        expect(deckSource, contains("// @FeatureOwned('$featureId')"));
        expect(deckSource, contains("// @XrayLayer('skin')"));
      },
    );
  });

  group('zfa xray check (criterion 4)', () {
    test('exits 0 on a clean slice', () async {
      FeatureSliceComposer().compose(
        projectRoot: tempDir.path,
        contract: contract,
        origin: 'contract.yaml',
      );

      final log = await runCapturing([
        'xray',
        'check',
        featureId,
        '--root=${tempDir.path}',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 0);
      expect(log, contains('Clean'));
    });

    test(
      'exits 1 and names the violator when a layer anchor is stripped',
      () async {
        FeatureSliceComposer().compose(
          projectRoot: tempDir.path,
          contract: contract,
          origin: 'contract.yaml',
        );
        // Sabotage: strip the anchor from a skin file.
        final viewFile = File(
          p.join(
            FeatureSliceComposer.sliceRootOf(tempDir.path, featureId),
            'skin',
            'views',
            'login_view.dart',
          ),
        );
        viewFile.writeAsStringSync(
          (viewFile.readAsStringSync()).replaceAll(
            "// @XrayLayer('skin')\n",
            '',
          ),
        );

        final log = await runCapturing([
          'xray',
          'check',
          featureId,
          '--root=${tempDir.path}',
        ]);
        expect(CliRunner.lastDispatchedExitCode, 1);
        expect(log, contains('login_view.dart'));
      },
    );

    test('exits 1 when a deck file lives outside the slice', () async {
      FeatureSliceComposer().compose(
        projectRoot: tempDir.path,
        contract: contract,
        origin: 'contract.yaml',
      );
      // A deck file attributed to the feature but NOT in the slice.
      File(p.join(tempDir.path, 'lib', 'rogue_deck.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync("// @FeatureOwned('$featureId')\nlibrary;\n");

      final log = await runCapturing([
        'xray',
        'check',
        featureId,
        '--root=${tempDir.path}',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 1);
      expect(log, contains('rogue_deck.dart'));
    });

    test('an unknown feature id is a usage error (exit 64)', () async {
      await runCapturing([
        'xray',
        'check',
        'no-such-feature',
        '--root=${tempDir.path}',
      ]);
      expect(CliRunner.lastDispatchedExitCode, 64);
    });
  });
}

/// Scaffolds the sandbox project: a declared contract for [featureId] plus
/// the engine + skin sources the slice composition discovers.
FeatureContract _scaffoldProject(Directory root) {
  final specDir = Directory(p.join(root.path, 'specs', featureId))
    ..createSync(recursive: true);
  File(p.join(specDir.path, 'contract.yaml')).writeAsStringSync('''
id: $featureId
display_name: Login UI
entities:
  - Login
routes:
  - /login
''');

  File(
      p.join(
        root.path,
        'lib',
        'src',
        'domain',
        'usecases',
        'login_usecase.dart',
      ),
    )
    ..createSync(recursive: true)
    ..writeAsStringSync('class LoginUsecase {}\n');
  File(
      p.join(
        root.path,
        'lib',
        'src',
        'presentation',
        'views',
        'login_view.dart',
      ),
    )
    ..createSync(recursive: true)
    ..writeAsStringSync('class LoginView {}\n');
  File(
      p.join(
        root.path,
        'lib',
        'src',
        'presentation',
        'widgets',
        'login_button.dart',
      ),
    )
    ..createSync(recursive: true)
    ..writeAsStringSync('class LoginButton {}\n');

  return FeatureContract(
    id: featureId,
    displayName: 'Login UI',
    entities: const ['Login'],
    routes: {'/login'},
  );
}
