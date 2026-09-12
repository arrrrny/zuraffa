// Bug #1518 (review fix) — the REAL `zfa tdd gen` prints the branched
// guard-only remedy, and its staleness mirror prints the SAME wording.
//
// The #1518 fast suite pins the WRITER's branching by constructing
// `BehaviorTestWriter(projectRoot:, featureDir:)` directly, and the
// driver suite pins the RUN side over a scripted fake `zfa`. Neither
// exercises gen's OWN seam-context threading (FR-004 / T4): with a
// legacy single-file feature the no-context conservative branch happens
// to print the same test-list wording, so deleting the threading kept
// the suite green. The lane-split shape is the distinguishing input —
// the writer must probe `tdd/04-ENGINE.md` from the gen-provided
// context, real write AND staleness mirror.
//
// Test map (fast tier — the real GenCommand, no pub get, no build):
//   G-1518-1 — legacy single-file feature (no lane plan on disk): the
//            printed warning names the test-list traces cell.
//   G-1518-2 — lane-split feature (`tdd/04-ENGINE.md` on disk): the
//            printed warning names the lane plan, and a SECOND gen run
//            (verdict=reused) reaches `_regenerateStaleStub`, whose
//            mirror prints the SAME lane-plan wording — the D4 "one
//            wording per gen output" claim.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmp;
  const feature = '1518-gen-seam';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug_1518_gen_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  /// Seed a spec.md + a fallback-routed unit test-list row: `FR-001` is a
  /// plain requirement (no declared contract row), the prose heuristics
  /// do not match, so the writer emits the bare UnimplementedError guard
  /// and the guard-only warning fires.
  Future<void> seedFeature() async {
    final featureDir = Directory(p.join(tmp.path, 'specs', feature));
    await featureDir.create(recursive: true);
    await File(p.join(featureDir.path, 'spec.md')).writeAsString('''
# Spec: $feature

## Functional Requirements

- **FR-001**: lets the user add a todo with a title
''');
    final tddDir = Directory(p.join(featureDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | lets the user add a todo with a title | FR-001 | PENDING |
''');
  }

  Future<String> runGen() async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'gen',
      'U1',
      '--project',
      tmp.path,
    ]);
    return out;
  }

  test('G-1518-1: legacy single-file feature — the real gen warning names '
      'the test-list traces cell, never 04-ENGINE', () async {
    await seedFeature();
    expect(
      File(
        p.join(tmp.path, 'specs', feature, 'tdd', '04-ENGINE.md'),
      ).existsSync(),
      isFalse,
    );

    final out = await runGen();

    expect(out, contains('zfa:tdd: guard-only'), reason: out);
    expect(
      out,
      contains(
        'hand-edit the test list '
        '(${p.join('specs', feature, 'tdd', 'test-list.md')}) '
        'traces cell',
      ),
      reason: out,
    );
    expect(out, isNot(contains('04-ENGINE')), reason: out);
  });

  test('G-1518-2: lane-split feature — the real gen warning names the lane '
      'plan, and the reused staleness mirror prints the SAME wording '
      '(FR-004 threading)', () async {
    await seedFeature();
    final tddDir = p.join(tmp.path, 'specs', feature, 'tdd');
    await File(
      p.join(tddDir, '04-ENGINE.md'),
    ).writeAsString('# Engine Plan: $feature\n');

    final first = await runGen();
    expect(first, contains('zfa:tdd: guard-only'), reason: first);
    expect(
      first,
      contains(
        'hand-edit the lane plan '
        '(${p.join('specs', feature, 'tdd', '04-ENGINE.md')}) traces cell',
      ),
      reason: first,
    );
    expect(first, isNot(contains('test-list.md')), reason: first);

    // Second run: the pair is owned and the subject is still an
    // UnimplementedError stub, so gen renders the staleness mirror
    // through the same writer — the mirror must print the SAME branched
    // wording (no second, contradictory remedy in one gen output).
    final second = await runGen();
    expect(second, contains('ownership: reused/reused'), reason: second);
    expect(second, contains('zfa:tdd: guard-only'), reason: second);
    expect(
      second,
      contains(
        'hand-edit the lane plan '
        '(${p.join('specs', feature, 'tdd', '04-ENGINE.md')}) traces cell',
      ),
      reason: second,
    );
    expect(second, isNot(contains('test-list.md')), reason: second);
  });
}
