// Spec 1098 — SandboxComposition decorator emission tests.
//
// The decorators connection: emit `@FeatureOwned('<feature>')` comment
// anchors onto composed sandbox artifacts so slice compositions, xray scans
// and the skin auditor share one persistent definition of the feature —
// read back by FeatureContractDecorators.scan, not guessed from paths.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract_decorators.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_composition.dart';
import 'package:zuraffa/src/plugins/slice/models/slice_manifest.dart';

void main() {
  late Directory workspace;
  late Directory sandboxDir;
  late List<String> generatedFiles;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_sandbox_deco_');
    sandboxDir = Directory(p.join(workspace.path, 'sandbox'));
    await sandboxDir.create(recursive: true);
    generatedFiles = [];
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

  void compose({required String? feature}) {
    const SandboxComposition().compose(
      projectRoot: workspace.path,
      sandboxDir: sandboxDir.path,
      feature: feature ?? 'login',
      routes: const [ManifestRoute(path: '/login', page: 'LoginView')],
      dependencies: const [
        ManifestDependency(
          dependency: 'LoginRepository',
          kind: 'remote',
          contract: 'Future<Either<Failure, User>> getUser(String id)',
          priority: 'P1',
          mockArtifact: 'lib/src/data/mock/fake_login_repository.dart',
        ),
      ],
      generatedFiles: generatedFiles,
    );
  }

  group('sandbox decorator emission', () {
    test('sandbox main.dart carries the @FeatureOwned anchor', () {
      compose(feature: 'login');

      final main = File(p.join(sandboxDir.path, 'lib', 'main.dart'));
      expect(main.existsSync(), isTrue);
      final source = main.readAsStringSync();
      expect(source, contains("// @FeatureOwned('login')"));
    });

    test('the emitted anchor is readable back by the decorator scanner', () {
      compose(feature: 'login');

      final grouped = FeatureContractDecorators.scan(sandboxDir.parent.path);
      final loginFiles = grouped['login'] ?? {};
      expect(
        loginFiles.any((f) => f.endsWith('main.dart')),
        isTrue,
        reason:
            'the sandbox must answer "which feature owns this file?" '
            'without path-convention guessing',
      );
    });

    test(
      'a feature id with non-word characters still emits a valid anchor',
      () {
        compose(feature: 'login-skin');

        final main = File(p.join(sandboxDir.path, 'lib', 'main.dart'));
        expect(
          main.readAsStringSync(),
          contains("// @FeatureOwned('login-skin')"),
        );
      },
    );

    test('emission is deterministic (identical inputs, identical bytes)', () {
      compose(feature: 'login');
      final first = File(
        p.join(sandboxDir.path, 'lib', 'main.dart'),
      ).readAsStringSync();

      compose(feature: 'login');
      final second = File(
        p.join(sandboxDir.path, 'lib', 'main.dart'),
      ).readAsStringSync();

      expect(first, second, reason: 'FR-007 determinism');
    });
  });
}
