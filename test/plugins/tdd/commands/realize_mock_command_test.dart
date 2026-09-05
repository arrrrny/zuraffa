import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_certification_sandbox.dart';
import 'package:zuraffa/src/plugins/mock/certification/mock_contract_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_mock_command.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

/// Spec 1009 (issue #1009) — `zfa tdd realize-mock <Entity>
/// --against=firestore`: the differential gate, driven through the real
/// command surface with the sandbox runner injected (the fast tier never
/// spawns dart subprocesses; the slow e2e test does).
///
/// Gate contract: exit 0 = all methods green on both tiers and diff none;
/// exit 1 = at least one divergence (the methods are named); exit 2 =
/// refusal (usage, missing artifacts, unsupported backend, red Tier-1
/// baseline). The receipt lands next to the contract artifacts and is
/// covered by a proof.v1 generation receipt `zfa proof check` verifies.
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  const loginEntity = '''
import 'package:zuraffa/mock.dart';

class Login {
  final String id;
  final String username;
  const Login({required this.id, required this.username});
}
''';

  const loginInterface = '''
import 'package:zuraffa/zuraffa.dart';
import '../../../domain/entities/login/login.dart';

abstract class LoginDataSource with Loggable, FailureHandler {
  Future<Login> get(QueryParams<Login> params);
  Future<Login> update(UpdateParams<String, LoginPatch> params);
  Future<Login> toggle(ToggleParams<String, Field<Login, dynamic>> params);
}
''';

  const committedTest = '''
// GENERATED - DO NOT EDIT
import 'package:test/test.dart';
import 'package:zuraffa/mock.dart';
import '../../../lib/src/domain/entities/login/login.dart';
import '../../../lib/src/data/datasources/login/login_datasource.dart';
import '../../../lib/src/data/datasources/login/login_mock_datasource.dart';
import '../../../lib/src/data/mock/login_mock_data.dart';

void main() {
  final LoginDataSource dataSource =
      LoginMockDataSource();

  group('Login mock contract (spec 1001)', () {
    test('get: exists, returns Future<Login>', () async {
      final Future<Login> Function(QueryParams<Login>) get\$ =
          dataSource.get;
      final value = await dataSource.get(QueryParams<Login>());
      expect(value, isA<Login>());
    });
    test('update: exists, returns Future<Login>', () async {
      final Future<Login> Function(UpdateParams<String, LoginPatch>) u\$ =
          dataSource.update;
      final value = await dataSource.update(UpdateParams<String, LoginPatch>(
          id: 'id 1', data: LoginPatch()));
      expect(value, isA<Login>());
    });
    test('toggle: exists, returns Future<Login>', () async {
      final Future<Login> Function(
          ToggleParams<String, Field<Login, dynamic>>) t\$ =
          dataSource.toggle;
      final value = await dataSource.toggle(ToggleParams<String,
          Field<Login, dynamic>>(id: 'id 1',
          field: const Field<Login, dynamic>('id'), value: 'toggled'));
      expect(value, isA<Login>());
    });
  });
}
''';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_rm_cmd_');
    projectRoot = tempDir.path;
    outputDir = p.join(projectRoot, 'lib', 'src');
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'login'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'login.dart')).writeAsString(loginEntity);
    final dsDir = Directory(p.join(outputDir, 'data', 'datasources', 'login'));
    await dsDir.create(recursive: true);
    await File(
      p.join(dsDir.path, 'login_datasource.dart'),
    ).writeAsString(loginInterface);
    await File(
      p.join(dsDir.path, 'login_mock_datasource.dart'),
    ).writeAsString('// GENERATED - DO NOT EDIT\n');
    final testDir = Directory(p.join(projectRoot, 'test', 'mock', 'login'));
    await testDir.create(recursive: true);
    await File(
      p.join(testDir.path, 'login_mock_contract_test.dart'),
    ).writeAsString(committedTest);
  });

  tearDown(() async {
    exitCode = 0;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MockCertificationRun runOf(Map<String, bool> outcomes) =>
      MockCertificationRun(
        analyzeIssues: 0,
        analyzeErrors: 0,
        passedTests: [
          for (final e in outcomes.entries)
            if (e.value) e.key,
        ],
        failedTests: [
          for (final e in outcomes.entries)
            if (!e.value) e.key,
        ],
        methodOutcomes: outcomes,
        runner: 'dart',
        logs: const ['(injected sandbox run)'],
      );

  Future<String> runRealizeMock({
    required Map<String, bool> tier1Outcomes,
    required Map<String, bool> tier2Outcomes,
    List<String> extraArgs = const [],
  }) async {
    final runs = <String, Map<String, bool>>{
      'tier1': tier1Outcomes,
      'tier2': tier2Outcomes,
    };
    final cmd = RealizeMockCommand(
      TddPlugin(),
      sandboxRunner:
          ({
            required tier,
            required entityName,
            required projectRoot,
            required outputDir,
            required contractTestSource,
            required methods,
            extraFiles,
          }) async {
            expect(runs.containsKey(tier), isTrue, reason: 'tier = $tier');
            expect(
              contractTestSource,
              isNotEmpty,
              reason: 'the committed/swapped test bytes travel to the sandbox',
            );
            if (tier == 'tier2') {
              expect(
                extraFiles,
                isNotEmpty,
                reason: 'the Tier-2 adapter rides along as an extra file',
              );
              expect(
                extraFiles!.keys.first,
                contains('login_tier2_firestore_mock_provider.dart'),
              );
            }
            return runOf(runs[tier]!);
          },
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final lines = <String>[];
    await runZoned(
      () => runner.run([
        'realize-mock',
        'Login',
        '--against',
        'firestore',
        '--project',
        projectRoot,
        ...extraArgs,
      ]),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return lines.join('\n');
  }

  group('clean differential (issue #1009 exit criterion 1)', () {
    test(
      'both tiers green → exit 0, clean receipt, proof check verifies',
      () async {
        final allGreen = {'get': true, 'update': true, 'toggle': true};
        final out = await runRealizeMock(
          tier1Outcomes: allGreen,
          tier2Outcomes: allGreen,
        );

        expect(exitCode, 0, reason: out);
        expect(out, contains('differential gate pass'));
        expect(out, contains('result=certified'));
        expect(
          out,
          contains('methods=3 tier1-green=3 tier2-green=3 diff-none=3'),
        );

        final receiptFile = File(
          p.join(
            projectRoot,
            'test',
            'mock',
            'login',
            'realize.Login.firestore.receipt.json',
          ),
        );
        expect(receiptFile.existsSync(), isTrue, reason: 'the receipt lands');
        final receipt = receiptFile.readAsStringSync();
        expect(receipt, contains('"spec": 1009'));
        expect(receipt, contains('"diff": "none"'));
        expect(receipt, contains('"result": "certified"'));

        // Machine-readable + parseable by zfa proof check: the #807
        // generation receipt covers the differential receipt's bytes.
        final proof = await ProofChecker(projectRoot: projectRoot).check();
        expect(proof.ok, isTrue, reason: 'findings: ${proof.findings}');
        expect(proof.receipts, greaterThanOrEqualTo(1));
        expect(
          proof.filesChecked,
          greaterThanOrEqualTo(1),
          reason: 'the realize receipt artifact is digest-verified',
        );
      },
    );
  });

  group('divergence (issue #1009 exit criterion 2)', () {
    test('a failing tier-2 method → exit 1 with the method named', () async {
      final out = await runRealizeMock(
        tier1Outcomes: {'get': true, 'update': true, 'toggle': true},
        tier2Outcomes: {'get': false, 'update': true, 'toggle': true},
      );

      expect(exitCode, 1, reason: out);
      expect(out, contains('MISMATCH'));
      expect(out, contains('diverges from the Tier-1 mock on: get'));
      expect(out, contains('divergence=get'));
      expect(out, contains('result=mismatch'));

      final receipt = File(
        p.join(
          projectRoot,
          'test',
          'mock',
          'login',
          'realize.Login.firestore.receipt.json',
        ),
      ).readAsStringSync();
      expect(receipt, contains('"tier1_result": "pass"'));
      expect(receipt, contains('"tier2_result": "fail"'));
      expect(receipt, contains('"diff": "mismatch"'));
    });
  });

  group('attribution honesty (the contract gate lesson)', () {
    test(
      'a red Tier-1 baseline with no divergence → refusal, not mismatch',
      () async {
        final out = await runRealizeMock(
          tier1Outcomes: {'get': false, 'update': false, 'toggle': false},
          tier2Outcomes: {'get': false, 'update': false, 'toggle': false},
        );

        expect(exitCode, 2, reason: out);
        expect(out, contains('BLOCKED'));
        expect(out, contains('Tier-1 contract itself is red'));
        expect(out, contains('not the Tier-2 adapter'));
        expect(out, contains('result=tier1-red'));
        expect(
          out,
          isNot(contains('MISMATCH')),
          reason: 'a broken baseline is never blamed on the adapter',
        );
      },
    );
  });

  group('refusals (errors-are-an-API)', () {
    test('missing entity → usage refusal', () async {
      final cmd = RealizeMockCommand(TddPlugin());
      final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
      await runner.run(['realize-mock', '--against', 'firestore']);
      expect(exitCode, 2);
    });

    test(
      'missing --against → usage refusal naming the supported backend',
      () async {
        final cmd = RealizeMockCommand(
          TddPlugin(),
          sandboxRunner:
              ({
                required tier,
                required entityName,
                required projectRoot,
                required outputDir,
                required contractTestSource,
                required methods,
                extraFiles,
              }) async => runOf(const <String, bool>{}),
        );
        final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
        await runner.run(['realize-mock', 'Login', '--project', projectRoot]);
        expect(exitCode, 2);
      },
    );

    test('unsupported --against → refusal naming firestore', () async {
      final cmd = RealizeMockCommand(
        TddPlugin(),
        sandboxRunner:
            ({
              required tier,
              required entityName,
              required projectRoot,
              required outputDir,
              required contractTestSource,
              required methods,
              extraFiles,
            }) async => runOf(const <String, bool>{}),
      );
      final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
      await runner.run([
        'realize-mock',
        'Login',
        '--against',
        'supabase',
        '--project',
        projectRoot,
      ]);
      expect(exitCode, 2);
    });

    test(
      'no committed contract test → refusal with the certify fix hint',
      () async {
        await File(
          p.join(projectRoot, MockContractTestWriter.contractTestPath('Login')),
        ).delete();

        final out = await runRealizeMock(
          tier1Outcomes: const {},
          tier2Outcomes: const {},
        );

        expect(exitCode, 2, reason: out);
        expect(out, contains('missing-contract-test'));
      },
    );

    test('--diverge naming an unknown method → refusal', () async {
      final out = await runRealizeMock(
        tier1Outcomes: {'get': true, 'update': true, 'toggle': true},
        tier2Outcomes: {'get': true, 'update': true, 'toggle': true},
        extraArgs: const ['--diverge', 'watch'],
      );

      expect(exitCode, 2, reason: out);
      expect(out, contains('unknown-diverge-method'));
    });
  });
}
