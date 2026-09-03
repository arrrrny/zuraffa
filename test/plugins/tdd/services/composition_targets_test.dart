// Unit tests for `CompositionTargets` (spec 052-acceptance-make-composition,
// T002: U1..U5) — the discovery service that resolves a feature's
// composable green unit subjects: unit-kind test-list rows ∩ green
// cycle-log evidence ∩ existing subject artifacts.
//
// Fast tier: the service reads files directly (no subprocess), so these
// tests drive it against a `TddFixture` in-process.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/composition_targets.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: '052-compose-targets');
    // The anchor subjects live under lib/ — create it before tests write
    // subject files into it (registerBehavior only records the path).
    await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
    // The canonical feature shape: one acceptance target + two units.
    await fx.seedTestList([
      (
        id: 'A-001',
        description: 'the signup flow completes and the account is usable',
        traces: 'FR-007',
        state: 'PENDING',
        kind: 'acceptance',
      ),
      (
        id: 'U-001',
        description: 'unit behavior backing A-001',
        traces: 'FR-007',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U-002',
        description: 'second unit behavior backing A-001',
        traces: 'FR-007',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(id: 'A-001', description: 'the signup flow');
    await fx.registerBehavior(id: 'U-001', description: 'unit behavior one');
    await fx.registerBehavior(id: 'U-002', description: 'unit behavior two');
  });

  tearDown(() {
    fx.dispose();
  });

  group('discovery resolves the composable anchors', () {
    test('U1: anchors are green unit subjects with existing files, in '
        'test-list order; green acceptance rows are never anchors', () async {
      await fx.seedGreenEvidence('U-001');
      await fx.seedGreenEvidence('U-002');
      await fx.seedGreenEvidence('A-001'); // green acceptance — must be ignored
      await File(fx.subjectPathOf('U-001')).writeAsString('int v1() => 1;\n');
      await File(fx.subjectPathOf('U-002')).writeAsString('int v2() => 2;\n');

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetResolved>());
      final anchors = (result as CompositionTargetResolved).anchors;
      expect(anchors.map((a) => a.behaviorId), ['U-001', 'U-002']);
      expect(anchors[0].subjectPath, fx.subjectPathOf('U-001'));
      expect(anchors[0].symbol, 'subject_u_001');
      expect(anchors[1].symbol, 'subject_u_002');
    });

    test('U2: zero composable anchors is the typed no-green-units result, '
        'not an exception', () async {
      // Units exist but carry no green evidence.
      await File(fx.subjectPathOf('U-001')).writeAsString('int v1() => 1;\n');

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetFailure>());
      final failure = result as CompositionTargetFailure;
      expect(failure.code, 'no-green-units');
      expect(failure.message, contains('no green unit subjects'));
    });

    test('U3: a green unit whose subject file is missing is a typed '
        'failure naming the artifact', () async {
      await fx.seedGreenEvidence('U-001');
      // The recorded subject file is never written — discovery must
      // refuse rather than hand back a partial anchor set.
      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetFailure>());
      final failure = result as CompositionTargetFailure;
      expect(failure.code, 'missing-anchor-subject');
      expect(failure.message, contains(fx.subjectPathOf('U-001')));
    });

    test('U4: the compose target never anchors against itself and a '
        'non-acceptance target fails the kind gate', () async {
      await fx.seedGreenEvidence('A-001');
      await fx.seedGreenEvidence('U-001');
      await File(fx.subjectPathOf('U-001')).writeAsString('int v1() => 1;\n');

      // Composing U-001 (unit-kind): even with green evidence and an
      // existing subject, the kind gate fails closed — composition is the
      // acceptance-subject surface only (spec Out of Scope).
      final unitTarget = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'U-001',
      );
      expect(unitTarget, isA<CompositionTargetFailure>());
      expect(
        (unitTarget as CompositionTargetFailure).code,
        'target-not-acceptance',
      );
    });

    test('U5: a malformed test list fails closed, naming the file', () async {
      await File(fx.testListPath).writeAsString(
        '# Test List: broken\n\n| A-001 | missing columns | FR-007 |\n',
      );
      await fx.seedGreenEvidence('U-001');
      await File(fx.subjectPathOf('U-001')).writeAsString('int v1() => 1;\n');

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetFailure>());
      final failure = result as CompositionTargetFailure;
      expect(failure.code, 'malformed-test-list');
      // The parse error names the file and the offending line.
      expect(failure.message, contains('test-list.md'));
      expect(failure.message, contains('line 3'));
    });
  });

  // -----------------------------------------------------------------
  // Issue #923: acceptance behaviors report `unexpressible` even when
  // the feature's unit subjects are ENTITY-WIRED (`wiredEntityAnchor`
  // marker emitted by `zfa tdd wire`) but not yet green — the compose
  // step refused to anchor against them. Discovery must treat an
  // entity-wired unit subject as a composable anchor even when the
  // unit behavior carries no green cycle-log evidence yet.
  // -----------------------------------------------------------------
  group('entity-wired anchors (issue #923)', () {
    /// The wire command's emitted implementation shape (bug #610): the
    /// subject carries the `wiredEntityAnchor` marker in executable code.
    String wiredSubject(String id, String entity) =>
        '''
// GENERATED IMPLEMENTATION — `zfa tdd wire $id` (bug #610).
library;

int subject_${id.toLowerCase().replaceAll('-', '_')}() {
  // Implementation anchor: references the generated entity this
  // behavior builds on.
  // ignore: unused_local_variable
  final Type wiredEntityAnchor = $entity;
  return 0;
}
''';

    test('U6: an entity-wired unit subject is a composable anchor even '
        'without green cycle-log evidence', () async {
      // U-001 was wired to the Task entity but never certified green —
      // exactly the spec-004 state the issue reports. Discovery must
      // still anchor it so the acceptance make can compose.
      await File(
        fx.subjectPathOf('U-001'),
      ).writeAsString(wiredSubject('U-001', 'Task'));

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetResolved>());
      final anchors = (result as CompositionTargetResolved).anchors;
      expect(anchors.map((a) => a.behaviorId), ['U-001']);
      expect(anchors.single.entityWired, isTrue);
    });

    test('U7: a plain (non-wired, non-green) unit stub is never an '
        'anchor — the honest no-green-units stop stands', () async {
      // gen's default stub carries no wiredEntityAnchor marker and the
      // row carries no green evidence: composing against it would be
      // composing against a lie.
      await File(fx.subjectPathOf('U-001')).writeAsString('int v1() => 1;\n');

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetFailure>());
      final failure = result as CompositionTargetFailure;
      expect(failure.code, 'no-green-units');
      expect(failure.message.toLowerCase(), contains('no green unit subjects'));
    });

    test('U8: green and entity-wired anchors resolve together in '
        'test-list order, each carrying its wiring status', () async {
      await fx.seedGreenEvidence('U-001');
      await File(fx.subjectPathOf('U-001')).writeAsString('int v1() => 1;\n');
      await File(
        fx.subjectPathOf('U-002'),
      ).writeAsString(wiredSubject('U-002', 'Task'));

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetResolved>());
      final anchors = (result as CompositionTargetResolved).anchors;
      expect(anchors.map((a) => a.behaviorId), ['U-001', 'U-002']);
      expect(anchors[0].entityWired, isFalse);
      expect(anchors[1].entityWired, isTrue);
    });

    test('U9: a wired marker inside a COMMENT is not an anchor (the '
        'marker must live in executable code)', () async {
      // Both comment shapes: the marker opening a comment line AND the
      // marker trailing real code — only executable code may anchor.
      await File(fx.subjectPathOf('U-001')).writeAsString(
        '// final Type wiredEntityAnchor = Task;\n'
        'int v1() => 1; // final Type wiredEntityAnchor = Task;\n',
      );

      final result = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A-001',
      );

      expect(result, isA<CompositionTargetFailure>());
      expect((result as CompositionTargetFailure).code, 'no-green-units');
    });
  });
}
