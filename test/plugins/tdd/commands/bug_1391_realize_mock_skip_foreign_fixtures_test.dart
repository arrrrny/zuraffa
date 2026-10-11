// Acceptance tests for issue #1391: realize-mock skips non-realize-diff
// fixtures — the #832 registry artifacts (`manifest.json`,
// `mock-cert.*.json`) that `zfa mock certify --feature` (issue #1001)
// writes into `specs/<feature>/tdd/fixtures/` crashed the differential
// gate (issue #1009) with `result=runner-error` because the fixture scan
// ingested every `.json` file as a realize-diff.v1 case.
//
// Drives the public CLI surface in-process (the realize_mock_command_test
// pattern: TddFixture + injectable suite runner / tier-1 driver / tier-2
// provider factory). The behaviors under test:
//   A1  the #1391 repro: certify artifacts + 3 contract cases -> gate
//       certifies, skip lines printed, no runner-error (AC-1),
//   A2  foreign documents of any shape are skipped with
//       `skipped <name> (schema <x>)` (AC-2),
//   A3  a foreign-only fixtures dir fails BLOCKED, never runner-error,
//       and never certifies an empty surface (AC-3),
//   A4  a pure realize-diff.v1 directory behaves unchanged (AC-4),
//   A5  a realize-diff.v1-stamped case that is malformed — missing
//       input.op (A5), no input map (A5a), non-object input (A5b), or
//       unparseable bytes that still carry the stamp (A5c) — fails
//       closed and never certifies the reduced surface (AC-5).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/tdd_fixture.dart';
import 'package:zuraffa/src/plugins/tdd/commands/realize_mock_command.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await fx.registerBehavior(
      id: 'B-101',
      description: 'create entity Login with email',
    );
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// Runs the command in-process with the zone print override (the
  /// realize command test pattern) and returns the captured output.
  Future<String> runRealizeMock({
    String entity = 'Login',
    String? against,
    String? feature,
    int tier1SuiteExit = 0,
    RealizeMockTier1Driver? tier1Driver,
  }) async {
    final cmd = RealizeMockCommand(
      TddPlugin(),
      suiteRunner: (paths, cwd) async =>
          (exitCode: tier1SuiteExit, output: 'suite exit $tier1SuiteExit'),
      tier1Driver: tier1Driver,
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    final args = <String>[
      'realize-mock',
      entity,
      '--project',
      fx.root.path,
      if (against != null) ...['--against', against],
      if (feature != null) ...['--feature', feature],
    ];
    final lines = <String>[];
    await runZoned(
      () => runner.run(args),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return lines.join('\n');
  }

  /// Writes one contract fixture (the realize-diff.v1 shape the committed
  /// contract cases follow).
  Future<void> writeFixture(
    String name, {
    required Map<String, dynamic> input,
    Map<String, dynamic>? mockOutput,
    List<Map<String, dynamic>>? seed,
  }) async {
    final dir = Directory(p.join(fx.featureDir, 'tdd', 'fixtures'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, name)).writeAsString(
      jsonEncode(<String, dynamic>{
        'schema': 'realize-diff.v1',
        'id': name.replaceAll('.json', ''),
        'input': input,
        'mockOutput': ?mockOutput,
        'seed': ?seed,
      }),
    );
  }

  /// Writes a raw JSON document into the fixtures directory (the entry
  /// point for the foreign artifacts under test).
  Future<void> writeRaw(String name, Object? document) async {
    final dir = Directory(p.join(fx.featureDir, 'tdd', 'fixtures'));
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, name),
    ).writeAsString(document is String ? document : jsonEncode(document));
  }

  /// The #832 fixture manifest (the `FixtureRegistry.writeManifest`
  /// document: schema 1, bug 832).
  Map<String, dynamic> manifestDoc() => <String, dynamic>{
    'schema': 1,
    'bug': 832,
    'families': ['login'],
    'files': {'login.json': 'a' * 64},
    'digest': 'b' * 64,
  };

  /// The #1001 mock-cert receipt (the `MockCertReceipt.toJson` document:
  /// schema 1, spec 1001).
  Map<String, dynamic> mockCertDoc() => <String, dynamic>{
    'schema': 1,
    'spec': 1001,
    'entity': 'Login',
    'interface': 'LoginRepository',
    'subject': 'lib/domain/repositories/login_repository.dart',
    'contract_test': 'test/mock/login/login_repository_test.dart',
    'contract_digest': 'c' * 64,
    'methods': [
      {'name': 'getById', 'satisfied': true},
    ],
    'sandbox': {'runner': 'dart', 'analyze_errors': 0},
    'certified_at': '2026-09-10T00:00:00.000Z',
  };

  /// The certified one-method contract surface (getById with a recorded
  /// oracle + seed).
  Future<void> writeGetByIdCase() async {
    await writeFixture(
      'get-by-id.json',
      input: const <String, dynamic>{'op': 'getById', 'id': 'u1'},
      mockOutput: const <String, dynamic>{
        'id': 'u1',
        'email': 'a@b.c',
        'attempts': 42,
      },
      seed: const <Map<String, dynamic>>[
        {'id': 'u1', 'email': 'a@b.c', 'attempts': 42},
      ],
    );
  }

  /// The certified three-method contract surface for Login (the issue
  /// #1391 repro's committed cases).
  Future<void> writeLoginContract() async {
    await writeGetByIdCase();
    await writeFixture(
      'save.json',
      input: const <String, dynamic>{
        'op': 'saveLogin',
        'id': 'u2',
        'email': 'd@e.f',
      },
      mockOutput: const <String, dynamic>{'id': 'u2'},
    );
    await writeFixture(
      'get-all.json',
      input: const <String, dynamic>{'op': 'getAllLogins'},
      mockOutput: const <String, dynamic>{
        'items': [
          {'id': 'u1', 'email': 'a@b.c', 'attempts': 42},
        ],
      },
      seed: const <Map<String, dynamic>>[
        {'id': 'u1', 'email': 'a@b.c', 'attempts': 42},
      ],
    );
  }

  String receiptPath() => p.join(
    fx.root.path,
    '.zfa',
    'receipts',
    'realize.Login.firestore.receipt.json',
  );

  Future<Map<String, dynamic>> readReceipt() async =>
      jsonDecode(await File(receiptPath()).readAsString())
          as Map<String, dynamic>;

  test('A1 (issue #1391 repro): #832 artifacts beside 3 contract cases are '
      'skipped — the gate certifies with no runner-error', () async {
    await writeLoginContract();
    await writeRaw('manifest.json', manifestDoc());
    await writeRaw('mock-cert.Login.json', mockCertDoc());

    final out = await runRealizeMock(against: 'firestore');

    // The gate certifies — the crash from the issue is gone.
    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=certified'));
    expect(out, contains('methods=3 mismatch=0'));
    expect(out, isNot(contains('runner-error')));
    expect(out, isNot(contains('carries no input map')));
    expect(out, isNot(contains('is not parseable JSON')));

    // The foreign files stay visible: skipped, with their schema.
    expect(out, contains('skipped manifest.json (schema 1)'));
    expect(out, contains('skipped mock-cert.Login.json (schema 1)'));

    // The receipt carries exactly the 3 real method records.
    final receipt = await readReceipt();
    expect(receipt['verdict'], 'certified');
    final methods = receipt['methods'] as List;
    expect(methods, hasLength(3));
    expect(methods.map((m) => (m as Map)['method']).toSet(), {
      'getById',
      'saveLogin',
      'getAllLogins',
    });
  });

  test('A2a: a foreign document with a string schema is skipped with its '
      'schema named', () async {
    await writeGetByIdCase();
    await writeRaw('foreign.json', <String, dynamic>{
      'schema': 'world-v2',
      'world': 'some-simulation-world',
    });

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('skipped foreign.json (schema world-v2)'));
    expect(out, contains('methods=1 mismatch=0'));
    expect(out, contains('result=certified'));
  });

  test('A2b: a schema-less document (valid input.op, no schema field) is '
      'skipped as unknown — the schema stamp is required', () async {
    await writeGetByIdCase();
    await writeRaw('schemaless.json', <String, dynamic>{
      'id': 'schemaless',
      'input': {'op': 'getById', 'id': 'u1'},
    });

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('skipped schemaless.json (schema unknown)'));
    expect(out, contains('methods=1 mismatch=0'));
  });

  test('A2c: an unparseable .json file is skipped as unknown — broken JSON '
      'no longer crashes the scan', () async {
    await writeGetByIdCase();
    await writeRaw('broken.json', '{not valid json');

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('skipped broken.json (schema unknown)'));
    expect(out, contains('methods=1 mismatch=0'));
    expect(out, contains('result=certified'));
  });

  test('A3: a foreign-only fixtures directory fails BLOCKED — an empty '
      'surface is never certified', () async {
    await writeRaw('manifest.json', manifestDoc());
    await writeRaw('mock-cert.Login.json', mockCertDoc());

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('result=blocked'));
    expect(out, isNot(contains('result=runner-error')));
    expect(out, isNot(contains('result=certified')));
    // The failure names the skip — the foreign files are discoverable.
    expect(
      out,
      contains(
        'no realize-diff.v1 contract cases remain after skipping 2 '
        'foreign document(s)',
      ),
    );
    // And no receipt is written for the empty surface.
    expect(File(receiptPath()).existsSync(), isFalse);
  });

  test('A4 (backward-compat pin): a pure realize-diff.v1 directory behaves '
      'unchanged — no skipped lines, same certified outcome', () async {
    await writeLoginContract();

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('result=certified'));
    expect(out, contains('methods=3 mismatch=0'));
    expect(out, isNot(contains('skipped ')));
    final receipt = await readReceipt();
    expect(receipt['verdict'], 'certified');
    expect(receipt['methods'], hasLength(3));
  });

  test('A5 (fail-closed pin): a realize-diff.v1-stamped case missing '
      'input.op still fails closed', () async {
    await writeGetByIdCase();
    await writeFixture(
      'broken-case.json',
      input: const <String, dynamic>{'id': 'u1'},
    );

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('carries no input.op'));
    expect(out, contains('result=runner-error'));
  });

  test('A5a (fail-closed pin): a realize-diff.v1-stamped case with no input '
      'map fails closed — no receipt for the reduced surface', () async {
    await writeGetByIdCase();
    await writeRaw('no-input.json', <String, dynamic>{
      'schema': 'realize-diff.v1',
      'id': 'no-input',
    });

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(
      out,
      contains('is stamped realize-diff.v1 but carries no input map'),
    );
    expect(out, contains('result=runner-error'));
    expect(out, isNot(contains('result=certified')));
    expect(File(receiptPath()).existsSync(), isFalse);
  });

  test('A5b (fail-closed pin): a realize-diff.v1-stamped case whose input is '
      'not an object fails closed', () async {
    await writeGetByIdCase();
    await writeRaw('bad-input.json', <String, dynamic>{
      'schema': 'realize-diff.v1',
      'id': 'bad-input',
      'input': 'not-an-object',
    });

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(
      out,
      contains('is stamped realize-diff.v1 but carries no input map'),
    );
    expect(out, contains('result=runner-error'));
    expect(File(receiptPath()).existsSync(), isFalse);
  });

  test('A5c (fail-closed pin): a truncated fixture that still carries the '
      'realize-diff.v1 stamp is a corrupt case, not a foreign file — it '
      'fails closed instead of silently shrinking the surface', () async {
    await writeGetByIdCase();
    await writeRaw(
      'truncated.json',
      '{"schema":"realize-diff.v1","input":{"op":"getById"',
    );

    final out = await runRealizeMock(against: 'firestore');

    expect(exitCode, 1, reason: 'out: $out');
    expect(
      out,
      contains('is not parseable JSON but is stamped realize-diff.v1'),
    );
    expect(out, contains('result=runner-error'));
    expect(out, isNot(contains('result=certified')));
    expect(out, isNot(contains('skipped truncated.json')));
    expect(File(receiptPath()).existsSync(), isFalse);
  });
}
