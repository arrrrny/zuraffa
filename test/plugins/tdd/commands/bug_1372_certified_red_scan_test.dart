// Issue #1372 — `_hasCertifiedRed` early-returned on the FIRST
// behavior-matching cycle-log section, so a stale `kind: error` section
// from an earlier failed attempt permanently shadowed a later certified
// red (`kind: red`) and `zfa tdd make` refused with not-certified-red
// even though `zfa tdd verify-red` had just certified the behavior.
//
// Fixed on master by 583d711d (issue #1353: scan EVERY section, return
// true when ANY matching section is kind: red) — this file is the
// regression pin the fix shipped without (issue #1372's own suggested
// test): a cycle-log carrying [error, red] for one behavior must let
// make proceed past the certified-red gate.
//
// Behaviors:
//   B1 — [error, red] ordering: make proceeds (no not-certified-red).
//   B2 — [red] alone: make proceeds (baseline shape unchanged).
//   B3 — [error] alone: make still refuses honestly.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // The behavior record make resolves (gen's own registry entry).
    await fx.registerBehavior(
      id: 'A1',
      description: 'create entity Login with email',
    );
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  Future<void> seedCycleLog(Iterable<String> kinds) async {
    final buf = StringBuffer('# Cycle log — ${fx.featureName}\n');
    var i = 0;
    for (final kind in kinds) {
      buf.write('## Cycle: c$i ($kind)\n\n');
      buf.write('- behavior: A1\n');
      buf.write('- kind: $kind\n');
      buf.write('- at: 2026-09-09T06:00:00.000Z\n');
      buf.write('- exit: 1\n');
      buf.write('- criterion: pinned regression section (issue #1372)\n');
      i++;
    }
    await File(
      p.join(fx.featureDir, 'tdd', 'cycle-log.md'),
    ).writeAsString(buf.toString());
  }

  Future<(int, String)> runMake() async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'make',
      'A1',
      '--project',
      fx.root.path,
    ]);
    return (exitCode, output);
  }

  test('B1: [error, red] ordering — make proceeds past the certified-red '
      'gate', () async {
    await seedCycleLog(['error', 'red']);

    final (code, output) = await runMake();

    expect(
      output,
      isNot(contains('has no certified-red evidence')),
      reason:
          'a later certified red is not shadowed by an earlier '
          'error section (the issue #1372 signature)',
    );
  });

  test('B2: [red] alone — make proceeds (baseline shape unchanged)', () async {
    await seedCycleLog(['red']);

    final (code, output) = await runMake();

    expect(output, isNot(contains('has no certified-red evidence')));
  });

  test('B3: [error] alone — make still refuses honestly', () async {
    await seedCycleLog(['error']);

    final (code, output) = await runMake();

    expect(output, contains('has no certified-red evidence'));
    expect(code, 1);
  });
}
