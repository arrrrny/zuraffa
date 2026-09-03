// Fast unit tests for `DifferentialGate` — real vs mock on the same
// committed fixtures, drift report, threshold from .zfa.json (spec 913,
// T003: U11-U13).
//
//   U11: per-field drift report from committed fixtures.
//   U12: threshold from .zfa.json; default 0.0 (strict) fails any drift.
//   U13: a missing fixtures directory is reported `skipped`, never
//        silently passed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_gate.dart';

void main() {
  late Directory temp;
  late String root;
  late String featureDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('diff_gate_');
    root = temp.path;
    featureDir = p.join(root, 'specs', '090-tdd-fixture');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  /// Two fixtures with committed mock outputs; the fake driver answers
  /// the REAL binding with one drifted field in the first fixture.
  Future<void> writeFixtures() async {
    final dir = p.join(featureDir, 'tdd', 'fixtures');
    await File(p.join(dir, 'get_by_id.json')).create(recursive: true);
    await File(p.join(dir, 'get_by_id.json')).writeAsString(
      jsonEncode({
        'schema': 'realize-diff.v1',
        'id': 'get-by-id-u1',
        'input': {'op': 'getById', 'id': 'u1'},
        'mockOutput': {'id': 'u1', 'email': 'a@b.c', 'active': true},
      }),
    );
    await File(p.join(dir, 'search.json')).writeAsString(
      jsonEncode({
        'schema': 'realize-diff.v1',
        'id': 'search-active',
        'input': {'op': 'search', 'active': true},
        'mockOutput': {
          'count': 2,
          'ids': ['u1', 'u2'],
        },
      }),
    );
  }

  Future<Map<String, dynamic>> driver(
    String binding,
    String entity,
    Map<String, dynamic> input,
  ) async {
    if (input['op'] == 'getById') {
      return binding == 'mock'
          ? {'id': 'u1', 'email': 'a@b.c', 'active': true}
          : {'id': 'u1', 'email': 'real@z.c', 'active': true};
    }
    return {
      'count': 2,
      'ids': ['u1', 'u2'],
    };
  }

  DifferentialGate gate() => DifferentialGate(
    featureDir: featureDir,
    projectRoot: root,
    driver: driver,
  );

  test('U11: per-field drift report from committed fixtures', () async {
    await writeFixtures();

    final result = await gate().run(entity: 'User');

    expect(result.fixturesRun, 2);
    expect(
      result.verdict,
      DifferentialVerdict.drift,
      reason: 'default threshold is 0.0 (strict) and one field drifted',
    );
    // 2 fields drifted of 5 compared (3 + 2 fields across the fixtures).
    expect(result.diffs, hasLength(2));
    final getById = result.diffs.firstWhere((d) => d.fixture == 'get-by-id-u1');
    expect(getById.compared, 3);
    expect(getById.drifted, 1);
    expect(
      getById.findings.map((f) => f.detail).join('\n'),
      allOf(contains('email'), contains('a@b.c'), contains('real@z.c')),
      reason: 'the finding must name the field and both values',
    );
    final search = result.diffs.firstWhere((d) => d.fixture == 'search-active');
    expect(search.drifted, 0, reason: 'identical outputs drift nothing');

    // The drift report is written with the #805-style findings.
    final reportFile = File(
      p.join(featureDir, 'tdd', 'differential-report.json'),
    );
    expect(reportFile.existsSync(), isTrue);
    final report =
        jsonDecode(await reportFile.readAsString()) as Map<String, dynamic>;
    expect(report['schema'], 'realize-diff.v1');
    expect(report['drift'], closeTo(1 / 5, 1e-9));
    expect(report['findings'], isNotEmpty);
  });

  test('U12: threshold from .zfa.json — 0.5 tolerates the 0.2 drift', () async {
    await writeFixtures();
    await File(p.join(root, '.zfa.json')).writeAsString(
      jsonEncode({
        'tdd': {'realizeDifferentialThreshold': 0.5},
      }),
    );

    final result = await gate().run(entity: 'User');

    expect(result.verdict, DifferentialVerdict.pass);
    expect(result.threshold, 0.5);
    expect(result.drift, closeTo(0.2, 1e-9));
  });

  test('U12b: default threshold 0.0 is strict — any drift fails', () async {
    await writeFixtures();
    // No .zfa.json at all.

    final result = await gate().run(entity: 'User');

    expect(result.threshold, 0.0);
    expect(result.verdict, DifferentialVerdict.drift);
  });

  test('U12c: drift exactly equal to the threshold PASSES (the boundary '
      'is <=, pinning the inclusive comparison)', () async {
    // One fixture, two fields, one drifted: drift = 1/2 = the threshold.
    final dir = p.join(featureDir, 'tdd', 'fixtures');
    await File(p.join(dir, 'get_by_id.json')).create(recursive: true);
    await File(p.join(dir, 'get_by_id.json')).writeAsString(
      jsonEncode({
        'schema': 'realize-diff.v1',
        'id': 'get-by-id-u1',
        'input': {'op': 'getById', 'id': 'u1'},
        'mockOutput': {'id': 'u1', 'email': 'a@b.c'},
      }),
    );
    await File(p.join(root, '.zfa.json')).writeAsString(
      jsonEncode({
        'tdd': {'realizeDifferentialThreshold': 0.5},
      }),
    );

    // A dedicated driver answering exactly the fixture's two fields.
    final result = await DifferentialGate(
      featureDir: featureDir,
      projectRoot: root,
      driver: (binding, entity, input) async => binding == 'mock'
          ? {'id': 'u1', 'email': 'a@b.c'}
          : {'id': 'u1', 'email': 'drifted@z.c'},
    ).run(entity: 'User');

    expect(result.drift, 0.5, reason: 'one drifted field of two compared');
    expect(result.threshold, 0.5);
    expect(
      result.verdict,
      DifferentialVerdict.pass,
      reason:
          'the threshold is INCLUSIVE: drift 0.5 at threshold 0.5 '
          'passes. A strict < comparison here would flip this verdict — '
          'this test pins the boundary.',
    );
  });

  test(
    'U13: a missing fixtures directory is skipped, never silently passed',
    () async {
      final result = await gate().run(entity: 'User');

      expect(result.verdict, DifferentialVerdict.skipped);
      expect(result.fixturesRun, 0);
      expect(result.diffs, isEmpty);
    },
  );
}
