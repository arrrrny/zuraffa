// Issue #1367 — realize-mock resolves entities EXCLUSIVELY through
// specs/<feature>/tdd/artifacts.json, while `zfa mock create --certify`
// writes its registry to test/mock/<snake>/mock-cert.<Entity>.json —
// the epic's two halves (#1001 certification → #1009 differential gate)
// could not compose: `zfa tdd realize-mock Login` answered
// `unknown entity` right after a successful certification.
//
// Fix under test (spec 1367-realize-mock-cert-fallback): when no
// artifacts registry names the entity, resolve through the certification
// receipt — its contract_test is the Tier-1 test and each certified
// method synthesizes a realize-diff.v1 case under
// .zfa/realize-mock/<entity>/fixtures/.
//
// Behaviors:
//   B1 — receipt-only entity resolves: contract test discovered, cases
//        synthesized per certified method, differential certified.
//   B2 — guard: no receipt + no registry → the honest unknown-entity
//        refusal stands.
//   B3 — unsatisfied methods in the receipt do not synthesize cases.
//   B4 — a receipt naming a MISSING contract test refuses honestly
//        (blocked), never unknown-entity.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:args/command_runner.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_mock_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/tier2_firestore/tier2_mock_provider.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

class _EchoProvider extends Tier2MockProvider {
  _EchoProvider() : super(entity: 'Login');

  @override
  Future<void> seed(List<Map<String, dynamic>> records) async {}

  @override
  Future<Map<String, dynamic>> invoke(
    String op,
    Map<String, dynamic> args,
  ) async {
    if (op == 'getById') return {'id': args['id'], 'attempts': '42'};
    return {'ok': op};
  }
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zfa-1367');
  });

  tearDown(() {
    exitCode = 0;
    root.deleteSync(recursive: true);
  });

  /// Seeds the mock certification receipt exactly as
  /// `zfa mock create Login --certify` writes it (MockCertReceipt.toJson).
  Future<void> seedCertReceipt({
    List<Map<String, dynamic>> methods = const [
      {'name': 'getById', 'satisfied': true},
      {'name': 'signIn', 'satisfied': true},
    ],
    String contractTest = 'test/mock/login/login_mock_contract_test.dart',
    bool writeContractTest = true,
  }) async {
    final testFile = File(
      p.join(
        root.path,
        'test',
        'mock',
        'login',
        'login_mock_contract_test.dart',
      ),
    );
    if (writeContractTest) {
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString('// certified contract test\n');
    }
    final receiptFile = File(
      p.join(root.path, 'test', 'mock', 'login', 'mock-cert.Login.json'),
    );
    await receiptFile.parent.create(recursive: true);
    await receiptFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 'mock-cert.v1',
        'entity': 'Login',
        'interface': 'AuthRepository',
        'contract_test': contractTest,
        'contract_digest': '0' * 64,
        'methods': methods,
        'certified_at': '2026-09-09T06:00:00.000Z',
      }),
    );
  }

  Future<(String output, int exit)> runRealizeMock({
    String entity = 'Login',
    String against = 'firestore',
  }) async {
    final cmd = RealizeMockCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async => (exitCode: 0, output: 'suite green'),
      tier1Driver: (entity, input) async {
        if (input['op'] == 'getById') {
          return {'id': input['id'], 'attempts': '42'};
        }
        return {'ok': input['op']};
      },
      tier2ProviderFactory: (entity) => _EchoProvider(),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final lines = <String>[];
    await runZoned(
      () => runner.run([
        'realize-mock',
        entity,
        '--project',
        root.path,
        '--against',
        against,
      ]),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return (lines.join('\n'), exitCode);
  }

  test(
    'B1: a certified entity resolves through the receipt and certifies',
    () async {
      await seedCertReceipt();

      final (output, exit) = await runRealizeMock();

      expect(
        output,
        isNot(contains('unknown entity')),
        reason: 'the certification registry is a resolution home',
      );
      expect(output, contains('tier-1 contract test: 1 file(s)'));
      expect(output, contains('verdict certified'));

      final fixturesDir = Directory(
        p.join(root.path, '.zfa', 'realize-mock', 'login', 'fixtures'),
      );
      expect(fixturesDir.existsSync(), isTrue, reason: output);
      final getById =
          jsonDecode(
                File(
                  p.join(fixturesDir.path, 'getById.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(getById['input']['op'], 'getById');
      expect(getById['schema'], 'realize-diff.v1');
    },
  );

  test('B2: guard — no receipt and no registry stays unknown-entity', () async {
    final (output, exit) = await runRealizeMock();
    expect(output, contains('unknown entity "Login"'));
    expect(exit, 1);
  });

  test('B3: unsatisfied methods do not synthesize cases', () async {
    await seedCertReceipt(
      methods: [
        {'name': 'getById', 'satisfied': true},
        {'name': 'signIn', 'satisfied': false},
      ],
    );

    final (output, exit) = await runRealizeMock();

    expect(output, isNot(contains('unknown entity')));
    final fixturesDir = Directory(
      p.join(root.path, '.zfa', 'realize-mock', 'login', 'fixtures'),
    );
    expect(File(p.join(fixturesDir.path, 'getById.json')).existsSync(), isTrue);
    expect(
      File(p.join(fixturesDir.path, 'signIn.json')).existsSync(),
      isFalse,
      reason: 'an unsatisfied method is not a proven surface',
    );
    expect(exit, 0);
  });

  test('B5: a receipt certifying no methods names the drift', () async {
    await seedCertReceipt(methods: []);

    final (output, exit) = await runRealizeMock();

    expect(output, isNot(contains('unknown entity')));
    expect(output, contains('certifies no methods'));
    expect(
      output,
      contains('--> fix: re-run `zfa mock create Login --certify`'),
    );
    expect(exit, 1);
  });

  test('B4: a receipt naming a missing contract test refuses blocked, '
      'never unknown-entity', () async {
    await seedCertReceipt(writeContractTest: false);

    final (output, exit) = await runRealizeMock();

    expect(output, isNot(contains('unknown entity')));
    expect(output, contains('no contract test for entity Login'));
    expect(exit, 1);
  });
}
