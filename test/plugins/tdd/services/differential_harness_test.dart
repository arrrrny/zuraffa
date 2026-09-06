// Fast unit tests for `DifferentialHarness` — the mock-era fixtures vs
// real-adapter contract differential (spec 1195, the REAL tier's honesty
// gate; parent #908, companion to `zfa tdd realize` #1193).
//
//   B-001: same-shape value drift on an entity field is NOT a divergence
//          (parity is shape, not bytes — the #915 convention).
//   B-002: entity-shape drift produces a NAMED row (fixture, field,
//          dimension, clause, input, mockOutput, realOutput).
//   B-003: state-transition drift is a row in the state dimension.
//   B-004: error-kind mismatch / one-sided error is a row in the error
//          dimension.
//   B-005: default threshold 0.0 is strict — any row is `divergence`;
//          the .zfa.json threshold escape hatch keeps the inclusive
//          boundary.
//   B-006: determinism — same fixtures, same receipt bytes; the digest
//          changes when the fixture set changes.
//   B-007: the receipt is journal-consumable (#1113): gate_state,
//          violations, refs.
//   B-008: no fixtures directory is `skipped` (not_assessed), never a
//          vacuous pass.
//   B-009: a driver failure is `runner-error` — the gate fails closed.
//   B-010: fixture `clauses` / `contract` maps override attribution and
//          comparison mode.
//   B-011: runner-error fixture counts track completed fixtures, not rows.
//   B-012: malformed optional fixture metadata fails closed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_harness.dart';

void main() {
  late Directory temp;
  late String root;
  late String featureDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('diff_harness_');
    root = temp.path;
    featureDir = p.join(root, 'specs', '1195-differential-harness');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  File fixtureFile(String name) =>
      File(p.join(featureDir, 'tdd', 'fixtures', name));

  Future<void> writeFixture(String name, Map<String, dynamic> doc) async {
    await fixtureFile(
      name,
    ).create(recursive: true).then((f) => f.writeAsString(jsonEncode(doc)));
  }

  /// The canonical `realize-diff.v1` fixture shape: committed input plus
  /// the certified mock-era output.
  Map<String, dynamic> fixture({
    required String id,
    required Map<String, dynamic> input,
    required Map<String, dynamic> mockOutput,
    Map<String, dynamic>? clauses,
    Map<String, dynamic>? contract,
  }) => {
    'schema': 'realize-diff.v1',
    'id': id,
    'input': input,
    'mockOutput': mockOutput,
    'clauses': ?clauses,
    'contract': ?contract,
  };

  /// A driver that answers the REAL binding from a canned table keyed by
  /// the input's `op` (the mock side comes from the recorded fixture
  /// output — the certified mock-era oracle).
  RealizeFixtureDriver driverFor(Map<String, Map<String, dynamic>> real) =>
      (binding, entity, input) async {
        expect(binding, 'real', reason: 'the mock side is the recorded output');
        final out = real[input['op'] as String];
        if (out == null) throw StateError('no canned real output');
        return out;
      };

  DifferentialHarness harness(RealizeFixtureDriver driver) =>
      DifferentialHarness(
        featureDir: featureDir,
        projectRoot: root,
        driver: driver,
        mode: 'diff-only',
      );

  Map<String, dynamic> receipt() =>
      jsonDecode(
            File(
              p.join(featureDir, 'tdd', 'differential-receipt.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('B-001: same-shape value drift on an entity field is not a '
      'divergence (parity is shape, not bytes)', () async {
    await writeFixture(
      'get_by_id.json',
      fixture(
        id: 'get-by-id-u1',
        input: const {'op': 'getById', 'id': 'u1'},
        mockOutput: const {'id': 'u1', 'email': 'mock@z.c'},
      ),
    );

    final result = await harness(
      driverFor(const {
        'getById': {'id': 'u1', 'email': 'real@z.c'},
      }),
    ).run(entity: 'User');

    expect(result.replayed, 1);
    expect(
      result.rows,
      isEmpty,
      reason:
          'string vs string is value drift, '
          'not a shape drift — the entity payload legitimately differs',
    );
    expect(result.verdict, DifferentialVerdict.pass);
    expect(result.divergence, 0.0);
  });

  test('B-002: entity-shape drift produces a NAMED row (fixture, field, '
      'dimension, clause, input, mockOutput, realOutput)', () async {
    await writeFixture(
      'get_by_id.json',
      fixture(
        id: 'get-by-id-u1',
        input: const {'op': 'getById', 'id': 'u1'},
        mockOutput: const {'id': 'u1', 'email': 'a@b.c', 'active': true},
      ),
    );

    final result = await harness(
      driverFor(const {
        'getById': {'id': 'u1', 'email': 'a@b.c', 'active': 'true'},
      }),
    ).run(entity: 'User');

    expect(result.verdict, DifferentialVerdict.divergence);
    // The drift: `active` is bool on the mock side, string on the real
    // side — a type (shape) break. `email` drifts only in value.
    expect(result.rows, hasLength(1));
    final row = result.rows.single;
    expect(row.fixture, 'get-by-id-u1');
    expect(row.field, 'active');
    expect(row.dimension, DiffDimension.entityShape);
    expect(row.clause, contains('entity shape'));
    expect(row.clause, contains('active'));
    // The four fields the issue names: input, mock output, real output,
    // contract clause.
    expect(row.input, {'op': 'getById', 'id': 'u1'});
    expect(row.mockOutput, {'id': 'u1', 'email': 'a@b.c', 'active': true});
    expect(row.realOutput, {'id': 'u1', 'email': 'a@b.c', 'active': 'true'});
    expect(row.detail, contains('bool'));
    expect(row.detail, contains('string'));
    expect(row.id, 'get-by-id-u1/active');
  });

  test(
    'B-003: state-transition drift is a row in the state dimension',
    () async {
      await writeFixture(
        'signup.json',
        fixture(
          id: 'signup-u2',
          input: const {'op': 'signup', 'email': 'x@y.z'},
          mockOutput: const {'id': 'u2', 'state': 'ACTIVE'},
        ),
      );

      final result = await harness(
        driverFor(const {
          'signup': {'id': 'u9', 'state': 'PENDING'},
        }),
      ).run(entity: 'User');

      expect(result.verdict, DifferentialVerdict.divergence);
      final row = result.rows.single;
      expect(row.field, 'state');
      expect(row.dimension, DiffDimension.stateTransition);
      expect(row.detail, contains('ACTIVE'));
      expect(row.detail, contains('PENDING'));
      expect(row.clause, contains('state transition'));
    },
  );

  test('B-004: error-kind mismatch and one-sided error presence are rows '
      'in the error-kind dimension', () async {
    await writeFixture(
      'get_by_id.json',
      fixture(
        id: 'get-by-id-missing',
        input: const {'op': 'getById', 'id': 'nope'},
        mockOutput: const {'error': 'not-found'},
      ),
    );
    await writeFixture(
      'delete.json',
      fixture(
        id: 'delete-missing',
        input: const {'op': 'delete', 'id': 'nope'},
        mockOutput: const {'deleted': false},
      ),
    );

    final result = await harness(
      driverFor(const {
        // Error KIND drifts: not-found vs gone.
        'getById': {'error': 'gone'},
        // The real side succeeds where the mock errored — wait, inverse:
        // the real side errors where the mock did not.
        'delete': {'deleted': false, 'error': 'conflict'},
      }),
    ).run(entity: 'User');

    expect(result.verdict, DifferentialVerdict.divergence);
    expect(result.rows, hasLength(2));
    final kindRow = result.rows.firstWhere(
      (r) => r.field == 'error' && r.fixture == 'get-by-id-missing',
    );
    expect(kindRow.dimension, DiffDimension.errorKind);
    expect(kindRow.detail, contains('not-found'));
    expect(kindRow.detail, contains('gone'));
    final oneSided = result.rows.firstWhere(
      (r) => r.fixture == 'delete-missing',
    );
    expect(oneSided.dimension, DiffDimension.errorKind);
    expect(oneSided.detail, contains('one side'));
  });

  test('B-005: default threshold 0.0 is strict — any row is divergence; '
      'the .zfa.json threshold keeps the inclusive boundary', () async {
    // One fixture, two fields, one shape-drift row: divergence ratio 1/2.
    await writeFixture(
      'get_by_id.json',
      fixture(
        id: 'get-by-id-u1',
        input: const {'op': 'getById', 'id': 'u1'},
        mockOutput: const {'id': 'u1', 'active': true},
      ),
    );
    final real = const {
      'getById': {'id': 'u1', 'active': 'true'},
    };

    // No .zfa.json: default 0.0 — strict.
    final strict = await harness(driverFor(real)).run(entity: 'User');
    expect(strict.threshold, 0.0);
    expect(strict.verdict, DifferentialVerdict.divergence);

    // Threshold 0.5 == the ratio 0.5: INCLUSIVE boundary passes (the
    // spec-913 semantics, pinned).
    await File(p.join(root, '.zfa.json')).writeAsString(
      jsonEncode({
        'tdd': {'realizeDifferentialThreshold': 0.5},
      }),
    );
    final tolerant = await harness(driverFor(real)).run(entity: 'User');
    expect(tolerant.threshold, 0.5);
    expect(tolerant.verdict, DifferentialVerdict.pass);
    // The row is still named — a consciously raised threshold is honest
    // reporting, never silence.
    expect(tolerant.rows, hasLength(1));
  });

  test('B-006: deterministic receipt — same fixtures, same bytes; the '
      'digest changes when the fixture set changes', () async {
    await writeFixture(
      'get_by_id.json',
      fixture(
        id: 'get-by-id-u1',
        input: const {'op': 'getById', 'id': 'u1'},
        mockOutput: const {'id': 'u1', 'state': 'ACTIVE'},
      ),
    );
    final real = const {
      'getById': {'id': 'u1', 'state': 'PENDING'},
    };

    final first = await harness(driverFor(real)).run(entity: 'User');
    final path = p.join(featureDir, 'tdd', 'differential-receipt.json');
    final bytes1 = await File(path).readAsBytes();

    // Replay: same fixtures, same driver answers → byte-identical bytes.
    await harness(driverFor(real)).run(entity: 'User');
    final bytes2 = await File(path).readAsBytes();
    expect(
      bytes2,
      bytes1,
      reason:
          'same fixtures must produce the same '
          'report bytes (replayable, like the spec-fuzz reports)',
    );

    // The receipt carries the fixture-set digest.
    final doc = receipt();
    expect(doc['fixtures']['digest'], startsWith('sha256:'));
    expect(doc['fixtures']['count'], 1);
    final digest1 = first.fixturesDigest;

    // Change the fixture set → the digest changes (replayability is
    // bound to the fixtures, not asserted).
    await writeFixture(
      'search.json',
      fixture(
        id: 'search-active',
        input: const {'op': 'search', 'active': true},
        mockOutput: const {'count': 0, 'ids': <String>[]},
      ),
    );
    final after = await harness(
      driverFor({
        ...real,
        'search': const {'count': 0, 'ids': <String>[]},
      }),
    ).run(entity: 'User');
    expect(after.fixturesDigest, isNot(digest1));
  });

  test('B-007: the receipt is journal-consumable (#1113) — schema, '
      'gate_state, violations, refs', () async {
    await writeFixture(
      'signup.json',
      fixture(
        id: 'signup-u2',
        input: const {'op': 'signup', 'email': 'x@y.z'},
        mockOutput: const {'id': 'u2', 'state': 'ACTIVE'},
      ),
    );

    await harness(
      driverFor(const {
        'signup': {'id': 'u9', 'state': 'PENDING'},
      }),
    ).run(entity: 'User');

    final doc = receipt();
    expect(doc['schema'], 'realize-diff-receipt.v1');
    expect(doc['feature'], '1195-differential-harness');
    expect(doc['entity'], 'User');
    expect(doc['verdict'], 'divergence');
    final journal = doc['journal'] as Map<String, dynamic>;
    expect(journal['gate_state'], 'red');
    expect(journal['violations'], ['signup-u2/state']);
    expect(
      (journal['refs'] as Map<String, dynamic>)['fixtures'],
      'specs/1195-differential-harness/tdd/fixtures',
    );
    expect(
      (journal['refs'] as Map<String, dynamic>)['receipt'],
      'specs/1195-differential-harness/tdd/differential-receipt.json',
    );
    // The named row is structured, not a string blob.
    final row = (doc['rows'] as List).single as Map<String, dynamic>;
    expect(row['input'], {'op': 'signup', 'email': 'x@y.z'});
    expect(row['mockOutput'], {'id': 'u2', 'state': 'ACTIVE'});
    expect(row['realOutput'], {'id': 'u9', 'state': 'PENDING'});
    expect(row['clause'], contains('state transition'));
  });

  test('B-008: no fixtures directory (or no .json files) is skipped, '
      'never a vacuous pass', () async {
    final missing = await harness((b, e, i) async => {}).run(entity: 'User');
    expect(missing.verdict, DifferentialVerdict.skipped);
    expect(missing.replayed, 0);
    expect(receipt()['journal']['gate_state'], 'not_assessed');

    // An existing but empty fixtures directory is also skipped — a
    // zero-fixture differential is not_assessed, not green.
    await Directory(
      p.join(featureDir, 'tdd', 'fixtures'),
    ).create(recursive: true);
    final empty = await harness((b, e, i) async => {}).run(entity: 'User');
    expect(empty.verdict, DifferentialVerdict.skipped);
  });

  test(
    'B-009: a driver failure is runner-error — the gate fails closed',
    () async {
      await writeFixture(
        'get_by_id.json',
        fixture(
          id: 'get-by-id-u1',
          input: const {'op': 'getById', 'id': 'u1'},
          mockOutput: const {'id': 'u1'},
        ),
      );

      final result = await harness(
        (binding, entity, input) async => throw StateError('driver blew up'),
      ).run(entity: 'User');

      expect(result.verdict, DifferentialVerdict.runnerError);
      expect(result.error, contains('driver blew up'));
      expect(receipt()['journal']['gate_state'], 'red');

      // An unparsable fixture is the same class (never a silent pass).
      await fixtureFile('broken.json').writeAsString('{not json');
      final unparsable = await harness(
        (b, e, i) async => {},
      ).run(entity: 'User');
      expect(unparsable.verdict, DifferentialVerdict.runnerError);
    },
  );

  test('B-010: fixture `clauses` and `contract` maps override attribution '
      'and comparison mode', () async {
    await writeFixture(
      'get_by_id.json',
      fixture(
        id: 'get-by-id-u1',
        input: const {'op': 'getById', 'id': 'u1'},
        mockOutput: const {'id': 'u1', 'email': 'a@b.c'},
        clauses: const {'email': 'SC-2: email must round-trip verbatim'},
        // Pin `email` to exact-value parity (an entity field, promoted to
        // contract by the fixture itself).
        contract: const {'email': 'value'},
      ),
    );

    final result = await harness(
      driverFor(const {
        'getById': {'id': 'u1', 'email': 'real@z.c'},
      }),
    ).run(entity: 'User');

    expect(result.verdict, DifferentialVerdict.divergence);
    final row = result.rows.single;
    expect(row.field, 'email');
    expect(row.clause, 'SC-2: email must round-trip verbatim');
    expect(row.detail, contains('a@b.c'));
    expect(row.detail, contains('real@z.c'));
  });

  test('B-011: runner-error counts completed fixtures independently of '
      'divergence rows', () async {
    await writeFixture(
      '01_clean.json',
      fixture(
        id: 'clean',
        input: const {'op': 'clean'},
        mockOutput: const {'id': 'u1'},
      ),
    );
    await writeFixture(
      '02_divergent.json',
      fixture(
        id: 'divergent',
        input: const {'op': 'divergent'},
        mockOutput: const {'state': 'ACTIVE', 'error': 'none'},
      ),
    );
    await fixtureFile('03_broken.json').writeAsString('{not json');

    final result = await harness(
      driverFor(const {
        'clean': {'id': 'u2'},
        'divergent': {'state': 'PENDING', 'error': 'conflict'},
      }),
    ).run(entity: 'User');

    expect(result.verdict, DifferentialVerdict.runnerError);
    expect(result.replayed, 2);
    expect(result.rows, hasLength(2));
    expect(receipt()['fixtures']['count'], 2);
    expect(receipt()['replayed'], 2);
  });

  for (final malformed in <String, Object>{
    'id': 7,
    'clauses': 'not-a-map',
    'contract': <Object>[],
  }.entries) {
    test(
      'B-012: malformed ${malformed.key} is a recorded runner-error',
      () async {
        await writeFixture('invalid.json', <String, dynamic>{
          'schema': 'realize-diff.v1',
          'id': 'valid-id',
          'input': const {'op': 'getById'},
          'mockOutput': const {'id': 'u1'},
          malformed.key: malformed.value,
        });
        var driverCalls = 0;

        final result = await harness((binding, entity, input) async {
          driverCalls++;
          return const {'id': 'u1'};
        }).run(entity: 'User');

        expect(result.verdict, DifferentialVerdict.runnerError);
        expect(result.replayed, 0);
        expect(driverCalls, 0);
        expect(receipt()['journal']['gate_state'], 'red');
      },
    );
  }
}
