// Fast unit tests for the `CompositionTargets` kind gate after issue
// #939: a widget-kind target composes like acceptance (against the
// feature's green unit subjects), and every refusal NAMES THE ACTUAL
// KIND — the pre-#939 message hardcoded "is unit-kind" for every
// non-acceptance kind, mislabeling widget rows (the make disengage said
// `behavior "A1" is unit-kind` for a widget row) and hiding the widget
// lane's real shape.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/composition_targets.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test('a widget-kind target passes the kind gate (composes like '
      'acceptance, issue #939)', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: 'the login page renders its controls',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'widget',
      ),
      (
        id: 'U-100',
        description: 'unit behavior backing A-100',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.registerBehavior(
      id: 'U-100',
      description: 'unit behavior backing A-100',
      writeTestFile: false,
    );
    await fx.seedGreenEvidence('U-100');
    await File(
      fx.subjectPathOf('U-100'),
    ).writeAsString('int subject_u_100() => 0;\n');

    final result = await const CompositionTargets().discover(
      projectRoot: fx.root.path,
      featureDir: fx.featureDir,
      behaviorId: 'A-100',
    );

    expect(result, isA<CompositionTargetResolved>());
    final resolved = result as CompositionTargetResolved;
    expect(resolved.anchors, hasLength(1));
    expect(resolved.anchors.single.behaviorId, 'U-100');
  });

  test('a widget-kind target with zero green anchors still honest-stops '
      'as no-green-units — NOT target-not-acceptance', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: 'the login page renders its controls',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);

    final result = await const CompositionTargets().discover(
      projectRoot: fx.root.path,
      featureDir: fx.featureDir,
      behaviorId: 'A-100',
    );

    expect(result, isA<CompositionTargetFailure>());
    expect((result as CompositionTargetFailure).code, 'no-green-units');
  });

  test('a unit-kind target still fails closed — and the message names '
      'unit-kind ACCURATELY', () async {
    await fx.seedTestList([
      (
        id: 'U-100',
        description: 'a unit behavior',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);

    final result = await const CompositionTargets().discover(
      projectRoot: fx.root.path,
      featureDir: fx.featureDir,
      behaviorId: 'U-100',
    );

    expect(result, isA<CompositionTargetFailure>());
    final failure = result as CompositionTargetFailure;
    expect(failure.code, 'target-not-acceptance');
    expect(failure.message, contains('is unit-kind:'));
  });

  test('a theme-kind target refuses with the ACTUAL kind named (the '
      'pre-#939 message mislabeled every kind as unit)', () async {
    await fx.seedTestList([
      (
        id: 'T-100',
        description: 'a theme harness behavior',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'unit', // placeholder — replaced by a theme section below
      ),
    ]);
    // Rewrite the list into the theme-harness shape (the fixture helper
    // only renders outer/inner sections).
    await File(fx.testListPath).writeAsString('''
# Test List: ${fx.featureName}

## Theme harness

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T-100 | a theme harness behavior | FR-939 | PENDING |
''');

    final result = await const CompositionTargets().discover(
      projectRoot: fx.root.path,
      featureDir: fx.featureDir,
      behaviorId: 'T-100',
    );

    expect(result, isA<CompositionTargetFailure>());
    final failure = result as CompositionTargetFailure;
    expect(failure.code, 'target-not-acceptance');
    // The row's ACTUAL kind — never a hardcoded "unit-kind" guess.
    expect(failure.message, contains('is theme-kind:'));
  });

  test('the shared reader contract keeps resolving widget rows as widget '
      '(TestListReader → BehaviorKind.widget, bug #830) — the kind the '
      'gate consumes', () async {
    await fx.seedTestList([
      (
        id: 'A-100',
        description: 'the login page renders its controls',
        traces: 'FR-939',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);

    final rows = await TestListReader(fx.featureDir).read();

    expect(rows.single.kind, BehaviorKind.widget);
  });
}
