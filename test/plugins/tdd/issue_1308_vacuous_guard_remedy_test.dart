// Issue #1308 — the vacuous-green remedy surfaces (fast tier).
//
// `zfa tdd gen` emits the bare UnimplementedError guard for a
// FALLBACK-ROUTED unit behavior (no `traces:` line to a declared contract
// row, prose heuristics unmatched), and `make`'s issue #1259 vacuous-green
// guard then refuses green on that exact shape — the two-cycle driver
// dead-ends with a generic stop that names neither the concept nor the
// remedy. The #1308 remediation is messaging-only:
//
//   1. gen (the writer) WARNS loudly when it emits a guard-only unit test
//      for a fallback-routed behavior, prescribing the exact remedy — the
//      test is still emitted, gen does not fail.
//   2. the run driver's vacuous-green make stop prescribes the exact
//      remedy on the fallback path (`stopped_at=<id>:make` preserved) and
//      surfaces the `zfa:tdd: vacuous-guard` marker as the DESIGNED
//      hand-delta seam on the traced entity/void path
//      (`stopped_at=<id>:hand` replaces the generic make stop) — driver
//      level, see issue_1308_vacuous_guard_remedy_driver_test.dart.
//
// Test map:
//   U-1308-1 — the shared remedy vocabulary exists with the exact strings
//              (one source in vacuous_guard.dart; FR-005).
//   U-1308-2 — the writer prints the loud guard-only warning after writing
//              a fallback guard-only unit test: token + behavior id +
//              remedy; the file is still written, byte-identical content
//              (FR-002).
//   U-1308-3 — NO fallback warning for the guarded paths: scalar declared
//              contract (typed assertion), prose-matched description
//              (`returns N`), traced entity/void contract (the marker
//              path, unchanged — FR-006/AC-4 backward compatibility).
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

/// Runs [body] and returns everything printed (via [ZoneSpecification.print])
/// as a single newline-joined string.
Future<String> capturePrint(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

Behavior fallbackBehavior(String id) => Behavior(
  id: id,
  feature: '1308-vacuous-guard-remedy',
  kind: BehaviorKind.unit,
  // No `returns N`, no `throws X` — the prose heuristics cannot match, so
  // a fallback-routed behavior lands on the bare guard (the issue's
  // repro: "lets the user add a todo with a title").
  description: 'lets the user add a todo with a title',
  sourceCriterion: 'FR-001',
  target: 'subjectUnderTest',
);

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('issue_1308_fast_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('U-1308-1: the shared remedy vocabulary carries the exact strings', () {
    // The exact remedy the acceptance criteria pin — gen's warning and the
    // run driver's stop message share ONE source (FR-005). Issue #1320:
    // the remedy also names the designed hand-delta seam.
    expect(
      vacuousGuardFallbackRemedy,
      'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
      're-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan '
      '(04-ENGINE.md) traces cell to FR-00N, Row.method and re-run '
      'zfa tdd gen (the designed hand-delta seam)',
    );
    // The machine-greppable warning token: distinct from the marker (the
    // fallback path's test does NOT carry the marker), greppable by the
    // run driver's forwarding scan.
    expect(vacuousGuardWarningToken, 'zfa:tdd: guard-only');
    expect(vacuousGuardWarningToken.contains(vacuousGuardMarker), isFalse);

    // The marker-presence predicate: the traced entity/void path's test
    // carries the marker, the fallback path's does not.
    expect(
      contentCarriesVacuousGuardMarker('// $vacuousGuardMarker\n'),
      isTrue,
    );
    expect(
      contentIsVacuousGreen(
        'final result = 0;\nexpect(result, isNot(isA<UnimplementedError>()));',
      ),
      isTrue,
    );

    // The hand-step journal line builder: names what to write and where.
    final violation = vacuousGuardHandStepViolation(
      behaviorId: 'U1',
      testPath: 'test/tdd/feat/u1_test.dart',
    );
    expect(violation, contains('hand-step=U1:hand'));
    expect(violation, contains(vacuousGuardMarker));
    expect(violation, contains('test/tdd/feat/u1_test.dart'));
    expect(violation, contains('assertion on the observable outcome'));
  });

  test(
    'U-1308-2: the writer warns on a fallback guard-only unit test and still writes it',
    () async {
      final testPath = p.join(tmp.path, 'u2_test.dart');
      final writer = const BehaviorTestWriter(); // contractShape: null
      final printed = await capturePrint(() async {
        await writer.write(
          behavior: fallbackBehavior('U2'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u2_subject.dart'),
        );
      });

      // The test file is STILL written (gen does not fail — FR-002).
      final file = File(testPath);
      expect(file.existsSync(), isTrue, reason: printed);
      final content = file.readAsStringSync();
      // The generated test shape is unchanged (FR-006): the bare guard.
      expect(
        content,
        contains('expect(result, isNot(isA<UnimplementedError>()));'),
      );
      expect(contentCarriesVacuousGuardMarker(content), isFalse);

      // The loud warning: the machine token, the behavior id, the gap, the
      // exact remedy — impossible to miss.
      expect(printed, contains(vacuousGuardWarningToken), reason: printed);
      expect(printed, contains('U2'));
      expect(printed, contains(vacuousGuardFallbackRemedy), reason: printed);
    },
  );

  test(
    'U-1308-3a: no fallback warning for a scalar declared contract',
    () async {
      final testPath = p.join(tmp.path, 'u3a_test.dart');
      const shape = UnitContractShape(
        declaredSignature: 'fetch(String id) -> bool',
        declaredReturn: 'bool',
        returnType: 'bool',
        params: [],
        scalarOutcome: true,
      );
      final writer = const BehaviorTestWriter(contractShape: shape);
      final printed = await capturePrint(() async {
        await writer.write(
          behavior: fallbackBehavior('U3A'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u3a_subject.dart'),
        );
      });
      final content = File(testPath).readAsStringSync();
      // The typed outcome assertion stands (issue #1259 remediation) — no
      // warning, no guard.
      expect(content, contains('expect(result, isA<bool>())'));
      expect(
        printed,
        isNot(contains(vacuousGuardWarningToken)),
        reason: printed,
      );
    },
  );

  test(
    'U-1308-3b: no fallback warning for a prose-matched description',
    () async {
      final testPath = p.join(tmp.path, 'u3b_test.dart');
      final writer = const BehaviorTestWriter();
      final printed = await capturePrint(() async {
        await writer.write(
          behavior: Behavior(
            id: 'U3B',
            feature: '1308-vacuous-guard-remedy',
            kind: BehaviorKind.unit,
            // "returns N" matches the prose heuristic — a real outcome
            // assertion derives (AC-4: existing specs are unchanged).
            description: 'returns 42 when invoked with no args',
            sourceCriterion: 'FR-001',
            target: 'subjectUnderTest',
          ),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u3b_subject.dart'),
        );
      });
      final content = File(testPath).readAsStringSync();
      expect(content, contains('expect(result, equals(42));'));
      expect(
        printed,
        isNot(contains(vacuousGuardWarningToken)),
        reason: printed,
      );
    },
  );

  test(
    'U-1308-3c: no fallback warning for a traced entity/void contract (the marker path)',
    () async {
      final testPath = p.join(tmp.path, 'u3c_test.dart');
      const shape = UnitContractShape(
        declaredSignature: 'login(AuthRequest) -> User',
        declaredReturn: 'User',
        returnType: 'Object?',
        params: [],
        scalarOutcome: false,
      );
      final writer = const BehaviorTestWriter(contractShape: shape);
      final printed = await capturePrint(() async {
        await writer.write(
          behavior: fallbackBehavior('U3C'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u3c_subject.dart'),
        );
      });
      final content = File(testPath).readAsStringSync();
      // The traced entity path keeps its #1259 marker (the designed
      // hand-delta seam — the run driver surfaces it, gen does not warn).
      expect(contentCarriesVacuousGuardMarker(content), isTrue);
      expect(
        printed,
        isNot(contains(vacuousGuardWarningToken)),
        reason: printed,
      );
    },
  );
}
