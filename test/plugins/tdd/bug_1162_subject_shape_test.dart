// Fast-tier tests for bug #1162 — bug subjects can never certify green:
// the subject-shape predicate that keeps the #1036 born-green refusal
// classes closed, and the bug-feature stub-only composition anchors that
// give prose bug scenarios a sanctioned path to green.
//
// The slow-tier end-to-end drives live in
// bug_1162_bug_subject_green_path_test.dart.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/composition_targets.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_shape.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('bug 1162: the born-green placeholder predicate', () {
    test('a hand-implemented subject is NOT a born-green placeholder', () {
      const raw = '''
library;

/// Scenario runner for behavior A1.
int a1_value() {
  final base = 40;
  final step = 2;
  return base + step;
}
''';
      expect(subjectIsBornGreenPlaceholder(raw), isFalse);
    });

    test('a still-throwing stub IS a placeholder', () {
      const raw = '''
library;

void subject_a1() => throw UnimplementedError('subject_a1 not implemented');
''';
      expect(subjectIsBornGreenPlaceholder(raw), isTrue);
    });

    test('the scaffolded-marker subject IS a placeholder', () {
      const raw = '''
// zfa:tdd: scaffolded — placeholder finders only
library;

void subject_a1() {}
''';
      expect(subjectIsBornGreenPlaceholder(raw), isTrue);
    });

    test('the #1036 func-scaffold literal body IS a placeholder', () {
      // `_renderScaffolded`'s default body: `return '<functionName>';`.
      const raw = '''
library;

String a1_value() {
  return 'a1_value';
}
''';
      expect(subjectIsBornGreenPlaceholder(raw), isTrue);
    });

    test('the declared-stub vacuous bodies ARE placeholders', () {
      for (final body in ['return 0;', 'return 0.0;', 'return true;']) {
        final raw = 'library;\n\nint a1_value() {\n  $body\n}\n';
        expect(
          subjectIsBornGreenPlaceholder(raw),
          isTrue,
          reason: 'body "$body" is the pipeline\'s vacuous scaffold class',
        );
      }
      expect(
        subjectIsBornGreenPlaceholder('library;\n\nint a1_value() => 0;\n'),
        isTrue,
        reason: 'the arrow-literal shape is the same vacuous class',
      );
    });

    test('an empty void body IS a placeholder (the #1036 void scaffold)', () {
      expect(
        subjectIsBornGreenPlaceholder('library;\n\nvoid a1_run() {\n}\n'),
        isTrue,
      );
    });

    test('a real implementation with a helper returning 0 is NOT a '
        'placeholder (only ALL-vacuous bodies classify)', () {
      const raw = '''
library;

int _helper() => 0;

int a1_value() {
  final step = _helper() + 42;
  return step;
}
''';
      expect(subjectIsBornGreenPlaceholder(raw), isFalse);
    });

    test('a compose-shaped body (anchor list + return 0) is NOT a '
        'placeholder — compose is the sanctioned pipeline', () {
      const raw = '''
// GENERATED IMPLEMENTATION — `zfa tdd compose A1`.
library;

import 'package:zuraffa/tdd/u1_subject.dart' as anchor0;

void subject_a1() {
  // Composition anchor: references the feature's unit subjects.
  // ignore: unused_local_variable
  final composedUnitAnchors = <Function>[anchor0.subject_u1];
}
''';
      expect(subjectIsBornGreenPlaceholder(raw), isFalse);
    });
  });

  group('bug 1162: bug-feature detection', () {
    test("a `bug-` prefixed feature dir is a bug feature", () {
      expect(
        CompositionTargets.isBugFeatureDir('/x/specs/bug-1162-fix'),
        isTrue,
      );
    });

    test('a normal numbered feature dir is not', () {
      expect(
        CompositionTargets.isBugFeatureDir('/x/specs/046-tdd-verify-red'),
        isFalse,
      );
    });

    test('a feature dir whose real path resolves under .specify/bugs is a '
        'bug feature (the specs/ bridge symlink)', () async {
      final tmp = await Directory.systemTemp.createTemp('bug1162_');
      addTearDown(() => tmp.delete(recursive: true));
      final bugDir = Directory(p.join(tmp.path, '.specify', 'bugs', 'my-bug'));
      await bugDir.create(recursive: true);
      final link = Link(p.join(tmp.path, 'specs', 'bug-my-bug'));
      await link.parent.create(recursive: true);
      await link.create(p.join(tmp.path, '.specify', 'bugs', 'my-bug'));
      expect(CompositionTargets.isBugFeatureDir(link.path), isTrue);
    });
  });

  group('bug 1162: stub-only composition anchors for bug features', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: 'bug-1162-fixture');
    });

    test('allowStubAnchors surfaces a registry-recorded on-disk stub unit '
        'subject as a [stub] anchor', () async {
      // The acceptance target (red-certified, prose scenario).
      await fx.seedCertifiedRed(
        id: 'A1',
        description:
            'it completes and a parseable baseline snapshot is '
            'cached (not a `timedOut: true` record).',
      );
      // The unit row: gen'd (registry + stub subject on disk) but NOT
      // green and NOT entity-wired — the #1162 bug-feature state.
      await fx.seedCertifiedRed(
        id: 'U1',
        description: 'the driver forwards its timeout override.',
        sourceCriterion: 'FR-001',
      );
      await fx.seedTestList([
        (
          id: 'A1',
          description:
              'it completes and a parseable baseline snapshot is '
              'cached (not a `timedOut: true` record).',
          traces: 'AC-1',
          state: 'PENDING',
          kind: 'acceptance',
        ),
        (
          id: 'U1',
          description: 'the driver forwards its timeout override.',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);

      // Default discovery: the honest no-green-units stop (unchanged).
      final strict = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A1',
      );
      expect(strict, isA<CompositionTargetFailure>());
      expect((strict as CompositionTargetFailure).code, 'no-green-units');

      // Stub-only discovery (bug features): the stub unit subject is the
      // anchor, honestly labeled.
      final relaxed = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A1',
        allowStubAnchors: true,
      );
      expect(relaxed, isA<CompositionTargetResolved>());
      final anchors = (relaxed as CompositionTargetResolved).anchors;
      expect(anchors, hasLength(1));
      expect(anchors.single.behaviorId, 'U1');
      expect(anchors.single.stubOnly, isTrue);
      expect(anchors.single.entityWired, isFalse);
    });

    test('stub-only discovery never anchors the target against itself and '
        'keeps failing closed when no unit subject exists on disk', () async {
      await fx.seedCertifiedRed(id: 'A1', description: 'prose scenario.');
      // No unit rows at all.
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'prose scenario.',
          traces: 'AC-1',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      final relaxed = await const CompositionTargets().discover(
        projectRoot: fx.root.path,
        featureDir: fx.featureDir,
        behaviorId: 'A1',
        allowStubAnchors: true,
      );
      expect(relaxed, isA<CompositionTargetFailure>());
      expect((relaxed as CompositionTargetFailure).code, 'no-green-units');
    });
  });
}
