// Spec 1115 — `zfa xray check <feature-id>` CLI contract.
//
// The check uses the slice's SliceBoundary (#1114 record) to verify:
//   * every file in the slice has an XrayLayer decorator matching its half;
//   * no file outside the slice is in the deck (feature-attributed by
//     @FeatureOwned but absent from the composed slice);
//   * no file in the slice is missing a layer.
// Exit 0 on a clean slice, 1 with named violators, 64 on usage errors.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract.dart';
import 'package:zuraffa/src/plugins/slice/generators/feature_slice_composer.dart';
import 'package:zuraffa/src/zfa_cli.dart';

const featureId = '004-login-ui';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('xray_check_cli_');
    final specDir = Directory(p.join(tempDir.path, 'specs', featureId))
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
          tempDir.path,
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
          tempDir.path,
          'lib',
          'src',
          'presentation',
          'views',
          'login_view.dart',
        ),
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('class LoginView {}\n');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  FeatureContract contract() => FeatureContract(
    id: featureId,
    displayName: 'Login UI',
    entities: ['Login'],
    routes: {'/login'},
  );

  test('a missing slice fails with the compose hint (exit 1)', () async {
    final log = await runCapturing([
      'xray',
      'check',
      featureId,
      '--root=${tempDir.path}',
    ]);
    expect(CliRunner.lastDispatchedExitCode, 1);
    expect(log, contains('slice compose'));
  });

  test(
    'a decorator mismatch against the slice half is named (exit 1)',
    () async {
      FeatureSliceComposer().compose(
        projectRoot: tempDir.path,
        contract: contract(),
        origin: 'contract.yaml',
      );
      // Sabotage: give the skin view an ENGINE anchor — location and
      // decorator disagree.
      final viewFile = File(
        p.join(
          FeatureSliceComposer.sliceRootOf(tempDir.path, featureId),
          'skin',
          'views',
          'login_view.dart',
        ),
      );
      viewFile.writeAsStringSync(
        (viewFile.readAsStringSync()).replaceFirst(
          "// @XrayLayer('skin')",
          "// @XrayLayer('engine')",
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
      expect(log, contains('skin'));
    },
  );

  test('the report prints the layer breakdown of the clean slice', () async {
    FeatureSliceComposer().compose(
      projectRoot: tempDir.path,
      contract: contract(),
      origin: 'contract.yaml',
    );

    final log = await runCapturing([
      'xray',
      'check',
      featureId,
      '--root=${tempDir.path}',
    ]);
    expect(CliRunner.lastDispatchedExitCode, 0);
    expect(log, contains(featureId));
    expect(log, contains('engine'));
    expect(log, contains('skin'));
  });
}
