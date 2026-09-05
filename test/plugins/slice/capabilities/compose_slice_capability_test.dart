// Spec 1098 — `zfa slice compose <featureId>` tests.
//
// Materialization step 6 (slice half): compose resolves the feature
// contract → SliceBoundary. The contract is the declared fact; compose
// validates the boundary against the real project and persists a
// compose.plan.json the sandbox/cut path can consume — no more re-deriving
// "what belongs to this feature" from string-path conventions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_contract_decorators.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/compose_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/slice_command.dart';

import '../helpers/capture_output.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_slice_compose_');
    File(
      p.join(workspace.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: compose_probe\nenvironment:\n  sdk: ^3.11.0\n');
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

  /// Writes a contract whose boundary interface file really exists.
  void writeLoginContract({bool createBoundaryFile = true}) {
    final boundaryFile = File(
      p.join(
        workspace.path,
        'lib/src/domain/repositories/login_repository.dart',
      ),
    );
    if (createBoundaryFile) {
      boundaryFile.parent.createSync(recursive: true);
      boundaryFile.writeAsStringSync('abstract class LoginRepository {}\n');
    }

    final specDir = Directory(p.join(workspace.path, 'specs', 'login'))
      ..createSync(recursive: true);
    File(p.join(specDir.path, 'contract.yaml')).writeAsStringSync('''
id: login
display_name: Login
xray_layer: presentation
entities:
  - User
routes:
  - /login
  - /login/forgot
boundary:
  type_name: LoginRepository
  interface_file: lib/src/domain/repositories/login_repository.dart
  mock_strategy: auto
''');
  }

  group('ComposeSliceCapability (spec 1098 step 6)', () {
    test(
      'resolves the contract into a compose plan with the boundary',
      () async {
        writeLoginContract();

        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isTrue, reason: result.message);

        final planFile = File(
          p.join(workspace.path, 'specs', 'login', 'compose.plan.json'),
        );
        expect(planFile.existsSync(), isTrue);

        final plan =
            jsonDecode(planFile.readAsStringSync()) as Map<String, dynamic>;
        expect(plan['schema'], 'compose.plan.v1');
        expect(plan['feature'], 'login');
        expect(plan['xray_layer'], 'presentation');
        expect(plan['entities'], ['User']);
        expect(plan['routes'], ['/login', '/login/forgot']);

        final boundary = plan['resolved_boundary'] as Map<String, dynamic>;
        expect(boundary['type_name'], 'LoginRepository');
        expect(
          boundary['interface_file'],
          'lib/src/domain/repositories/login_repository.dart',
        );
        expect(boundary['mock_strategy'], 'auto');
      },
    );

    test('the plan carries the @FeatureOwned decorator line', () async {
      writeLoginContract();

      final result = await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      final planFile = File(
        p.join(workspace.path, 'specs', 'login', 'compose.plan.json'),
      );
      final plan =
          jsonDecode(planFile.readAsStringSync()) as Map<String, dynamic>;

      expect(plan['decorator'], FeatureContractDecorators.ownedLine('login'));
      expect(result.success, isTrue);
    });

    test('an unknown feature id fails with the known ids listed', () async {
      writeLoginContract();

      final result = await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'checkout',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('checkout'));
      expect(
        result.message,
        contains('login'),
        reason: 'actionable failure: list what IS known',
      );
    });

    test('a boundary whose interface file is missing fails honestly', () async {
      writeLoginContract(createBoundaryFile: false);

      final result = await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      expect(result.success, isFalse);
      expect(
        result.message,
        contains('login_repository.dart'),
        reason: 'the failure names the unresolved boundary file',
      );
    });

    test(
      'a project without that spec dir fails without a stack trace',
      () async {
        final result = await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'nope',
        );

        expect(result.success, isFalse);
        expect(result.message, contains('nope'));
      },
    );
  });

  group('slice compose dispatch (INV-1)', () {
    late CommandRunner<void> runner;
    late SliceCommand command;

    setUp(() {
      command = SliceCommand(projectRoot: workspace.path);
      runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    });

    test('zfa slice compose <unknown> fails with a usage error', () async {
      writeLoginContract();

      final output = await captureOutput(
        () => runner.run(['slice', 'compose', 'checkout']),
      );

      expect(output, contains('checkout'));
      expect(command.exitCode, isNot(0));
    });

    test('zfa slice compose without an id fails with usage text', () async {
      final output = await captureOutput(
        () => runner.run(['slice', 'compose']),
      );

      expect(output, contains('usage'), reason: 'INV-1: usage, not stack');
      expect(command.exitCode, 64);
    });
  });
}
