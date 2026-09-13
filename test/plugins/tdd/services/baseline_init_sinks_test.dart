// Issue #1528 (review follow-up): `zfa tdd init`'s writer streams are part
// of its observable contract — every `✗ <writer>: <error>` line goes to
// stdout, exactly as the pre-#1528 inline loop wrote it, and only the
// trailing misfire block goes to stderr. `TddBaselineInit.ensure` keeps the
// two as distinct sinks (`onError` / `onMisfire`) so `zfa tdd init` can
// restore that split; the entry preflight still passes one sink for all
// three.
//
// A pubspec-less temp root makes the dev_dependencies patcher misfire with
// a `StateError`, so both the per-writer `✗` line and the trailing misfire
// block are produced in one pass.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/baseline_init.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('baseline_sinks_'));
  tearDown(() => root.deleteSync(recursive: true));

  test('✗ writer lines and the misfire block use their own sinks', () async {
    final lines = <String>[];
    final errors = <String>[];
    final misfires = <String>[];

    await expectLater(
      const TddBaselineInit().ensure(
        projectRoot: root.path,
        onLine: lines.add,
        onError: errors.add,
        onMisfire: misfires.add,
      ),
      throwsA(isA<BaselineInitMisfire>()),
    );

    expect(
      errors,
      contains(matches(RegExp(r'✗ .*pubspec\.yaml dev_dependencies'))),
      reason: 'the writer diagnosis stays on the error sink',
    );
    expect(
      misfires.any((line) => line.contains('misfire')),
      isTrue,
      reason: 'the trailing misfire block is written to its own sink',
    );
    expect(
      errors.any((line) => line.contains('misfire')),
      isFalse,
      reason: 'the misfire block must not ride the writer sink',
    );
    expect(
      misfires.any((line) => line.startsWith('   ✗')),
      isFalse,
      reason: 'no ✗ writer line rides the misfire sink',
    );
  });
}
