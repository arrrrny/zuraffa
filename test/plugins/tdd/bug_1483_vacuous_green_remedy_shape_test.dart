// Bug #1483 — the vacuous-green remedy vocabulary (fast tier).
//
// Issue #1320 introduced the shared remedy wording with the lane plan
// hardcoded: "hand-edit the lane plan (04-ENGINE.md) traces cell". For a
// LEGACY single-file feature (no `## Lanes` in its spec) there is no
// 04-ENGINE.md and there never will be — the real seam is the traces
// cell of `tdd/test-list.md`. `vacuousGuardFallbackRemedyFor` branches
// the remedy by feature shape and carries the FULL path of the file to
// edit; the pre-#1483 shared constant stays byte-identical (the writer,
// the run driver's forwarding scan and the #1320 suite pin it).
//
// Test map:
//   U-1483-1a — the single-file shape names the test list's traces cell
//            (full path), never the lane plan; the shared halves stay
//            verbatim.
//   U-1483-1b — the lane-split shape names the lane plan's traces cell
//            (full path), never the test list.
//   U-1483-1c — the pre-#1483 shared constant is unchanged.
//
// The driver-level suites (the REAL stop message over the REAL
// RunDriverCore) live in bug_1483_vacuous_green_remedy_driver_test.dart
// (the slow tier).
library;

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

void main() {
  test('U-1483-1a: the single-file shape names the TEST LIST traces cell '
      '(full path), never the lane plan', () {
    final remedy = vacuousGuardFallbackRemedyFor(
      lanePlanPath: null,
      testListPath: p.join('specs', '001-todo-app', 'tdd', 'test-list.md'),
    );
    // The hand-delta seam is the file the feature ACTUALLY carries.
    expect(
      remedy,
      contains(
        'hand-edit the test list '
        '(${p.join('specs', '001-todo-app', 'tdd', 'test-list.md')}) '
        'traces cell',
      ),
      reason: remedy,
    );
    expect(remedy, isNot(contains('04-ENGINE')), reason: remedy);
    // The shared halves stay verbatim (one wording family, issue
    // #1308/#1320): the re-plan advice first, the seam tail last.
    expect(
      remedy,
      contains(
        'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
        're-run zfa tdd gen, re-run zfa tdd run — or hand-edit the ',
      ),
      reason: remedy,
    );
    expect(
      remedy,
      contains('FR-00N, Row.method and re-run zfa tdd gen'),
      reason: remedy,
    );
    expect(remedy, endsWith('(the designed hand-delta seam)'), reason: remedy);
  });

  test('U-1483-1b: the lane-split shape names the LANE PLAN traces cell '
      '(full path)', () {
    final remedy = vacuousGuardFallbackRemedyFor(
      lanePlanPath: p.join('specs', '1008-two-cycle', 'tdd', '04-ENGINE.md'),
      testListPath: p.join('specs', '1008-two-cycle', 'tdd', 'test-list.md'),
    );
    expect(
      remedy,
      contains(
        'hand-edit the lane plan '
        '(${p.join('specs', '1008-two-cycle', 'tdd', '04-ENGINE.md')}) '
        'traces cell',
      ),
      reason: remedy,
    );
    expect(remedy, isNot(contains('test-list.md')), reason: remedy);
    expect(remedy, endsWith('(the designed hand-delta seam)'), reason: remedy);
  });

  test('U-1483-1c: the pre-#1483 shared constant is unchanged (the '
      'writer, the forwarding scan and #1320 pin it)', () {
    expect(
      vacuousGuardFallbackRemedy,
      'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
      're-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan '
      '(04-ENGINE.md) traces cell to FR-00N, Row.method and re-run '
      'zfa tdd gen (the designed hand-delta seam)',
    );
  });
}
