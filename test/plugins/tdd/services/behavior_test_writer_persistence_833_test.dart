// Bug #833 (tdd-persistence-test-harness) — the persistence test shape of
// `BehaviorTestWriter`.
//
// When the plan marks a behavior persistence-kind (`[persistence]` marker,
// parsed into `Behavior.persistence`), `zfa tdd gen` must generate the
// test WITH the persistence harness wired in:
//
//   1. a fresh temp-directory box set bootstrapped per test and torn down
//      per test (setUp/tearDown);
//   2. the injected test clock (`TestClock.advanceTime`) so TTL assertions
//      never need real sleeps;
//   3. the corruption drill + registrar gate available through the harness
//      import (package:zuraffa/zuraffa.dart).
//
// Non-persistence behaviors keep the exact pre-#833 test shape — the plain
// function test must not grow harness imports or lifecycle boilerplate.
//
// These tests are content assertions by design: the generated persistence
// test imports `package:zuraffa/zuraffa.dart`, which only resolves in a
// user project (or this package), not in a bare fixture — the honest-red
// e2e for the plain shape is already pinned by behavior_test_writer_test.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('writer_persistence_833_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Behavior behavior({
    bool persistence = false,
    String description = 'cached entity survives a TTL expiry cycle',
  }) => Behavior(
    id: 'U1',
    feature: '005-caching',
    kind: BehaviorKind.unit,
    description: description,
    sourceCriterion: 'FR-001',
    target: 'subjectU1',
    persistence: persistence,
  );

  Future<String> writeFor(Behavior b) async {
    final testPath = p.join(tmpDir.path, 'u1_test.dart');
    final subjectPath = p.join(tmpDir.path, 'u1_subject.dart');
    await const BehaviorTestWriter().write(
      behavior: b,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    return File(testPath).readAsString();
  }

  group('BehaviorTestWriter — persistence-kind shape (bug #833)', () {
    test(
      'persistence behavior wires the harness: per-test temp-box lifecycle',
      () async {
        final content = await writeFor(behavior(persistence: true));
        expect(
          content,
          contains("import 'package:zuraffa/zuraffa.dart';"),
          reason: 'the harness ships in the package surface',
        );
        expect(content, contains('PersistenceTestHarness'));
        expect(
          content,
          contains('bootstrap()'),
          reason: 'a fresh temp-directory box set per test',
        );
        expect(content, contains('setUp('));
        expect(
          content,
          contains('tearDown('),
          reason: 'the box set is torn down per test, never shared',
        );
        expect(content, contains('teardown()'));
      },
    );

    test(
      'persistence behavior injects the test clock — no real sleeps',
      () async {
        final content = await writeFor(behavior(persistence: true));
        expect(content, contains('TestClock'));
        expect(
          content,
          contains('advanceTime'),
          reason: 'TTL assertions advance the clock virtually',
        );
        expect(
          content,
          isNot(contains('Future.delayed')),
          reason: 'no real sleeps in the suite',
        );
        expect(content, isNot(contains('Future<void>.delayed')));
        expect(content, isNot(contains('sleep(')));
      },
    );

    test(
      'persistence behavior keeps the honest-red assertion capture',
      () async {
        final content = await writeFor(behavior(persistence: true));
        expect(content, contains('on UnimplementedError catch'));
        expect(content, contains('U1'));
        expect(content, contains('FR-001'));
        expect(content, contains('subject.subjectU1'));
        // The marker itself must never leak into the generated test prose.
        expect(content, isNot(contains('[persistence]')));
      },
    );

    test(
      'persistence behavior exposes a corruption drill + registrar gate path',
      () async {
        final content = await writeFor(behavior(persistence: true));
        expect(
          content,
          contains('boxNames:'),
          reason: 'the test declares its per-test box set',
        );
        expect(
          content,
          contains('seedCorruptedBox'),
          reason: 'the corruption drill surface is documented in the test',
        );
        expect(
          content,
          contains('RegistrarGateError'),
          reason: 'the registrar gate surface is documented in the test',
        );
      },
    );

    test(
      'NON-persistence behavior keeps the plain shape — no harness, no boilerplate',
      () async {
        final content = await writeFor(
          behavior(
            persistence: false,
            description: 'returns 42 when invoked with no args',
          ),
        );
        expect(
          content,
          isNot(contains('package:zuraffa/zuraffa.dart')),
          reason: 'the plain shape must not grow a package import',
        );
        expect(content, isNot(contains('PersistenceTestHarness')));
        expect(content, isNot(contains('TestClock')));
        expect(content, isNot(contains('bootstrap()')));
        expect(content, isNot(contains('tearDown(')));
        // Honest red unchanged.
        expect(content, contains('on UnimplementedError catch'));
        expect(content, contains('42'), reason: 'numeric assertion preserved');
      },
    );
  });
}
