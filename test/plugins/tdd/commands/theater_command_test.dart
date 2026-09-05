/// Acceptance behaviors A5–A7 for `zfa tdd theater` (spec
/// 1006-tdd-theater-replay-tui, tdd/test-list.md) — driving the real CLI
/// entry point in-process (`CliRunner.runCapturing`, the sc_001–sc_012
/// pattern).
///
/// The tests run with a non-TTY stdout (the dart test harness pipes
/// output), so they exercise the honest non-TTY contract of the command:
/// refuse to start the TUI, print the actionable message + machine
/// summary line, exit 1 — and prove the read-only contract by hashing the
/// whole fixture project (including `.zfa/` and `specs/`) before/after.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tree_snapshot.dart';

import '../theater/theater_fixture.dart';

void main() {
  late CliRunner runner;

  setUp(() {
    runner = CliRunner(exitOnCompletion: false);
  });

  tearDown(() {
    exitCode = 0;
  });

  Future<String> drive(TheaterFixture fx) => runner.runCapturing([
    'tdd',
    'theater',
    fx.featureName,
    '--project',
    fx.root.path,
  ]);

  String lastLine(String out) =>
      out.trim().split('\n').where((l) => l.trim().isNotEmpty).last;

  group('zfa tdd theater', () {
    test('A5: non-TTY refuses with the summary line', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final out = await drive(fx);

      // The actionable refusal message (TTY guard discipline).
      expect(out, contains('interactive terminal'));
      expect(out, contains(fx.featureName));
      // The machine summary line is the final stdout line.
      expect(
        lastLine(out),
        'theater: feature=${fx.featureName} behaviors=3 cycles=3 '
        'receipts=2 result=non-tty',
      );
      expect(exitCode, 1);

      // A `specs/`-prefixed feature id resolves to the same feature
      // (the replay-surface resolution rule).
      final prefixed = await runner.runCapturing([
        'tdd',
        'theater',
        'specs/${fx.featureName}',
        '--project',
        fx.root.path,
      ]);
      expect(
        lastLine(prefixed),
        'theater: feature=${fx.featureName} behaviors=3 cycles=3 '
        'receipts=2 result=non-tty',
      );

      // A path-shaped feature id is rejected as a usage error, never
      // traversed — including the backslash, `.` and `..` shapes (every
      // disjunct of the validation).
      for (final bad in ['specs/../etc', r'has\backslash', '.', '..']) {
        final pathy = await runner.runCapturing([
          'tdd',
          'theater',
          bad,
          '--project',
          fx.root.path,
        ]);
        expect(pathy, contains('invalid feature'), reason: 'feature "$bad"');
        expect(pathy, contains('single spec directory name'));
        exitCode = 0;
      }

      // No feature id at all: the usage error names the requirement.
      final noArg = await runner.runCapturing([
        'tdd',
        'theater',
        '--project',
        fx.root.path,
      ]);
      expect(noArg, contains('Feature id is required'));
    });

    test('A6: the theater writes nothing', () async {
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final before = await TreeSnapshot.capture(
        fx.root.path,
        trees: ['specs', 'lib', 'test', '.zfa', '.'],
      );
      await drive(fx);
      final after = await TreeSnapshot.capture(
        fx.root.path,
        trees: ['specs', 'lib', 'test', '.zfa', '.'],
      );

      // Read-only end to end: byte-identical trees, no new files.
      expect(before.changedPaths(after), isEmpty);
      expect(after.entries.keys, contains('pubspec.yaml'));
      expect(after.changedPaths(before), isEmpty);
    });

    test('A7: unknown / pending / missing-registry paths fail or load '
        'honestly', () async {
      // Unknown feature: exit 1, the id named.
      final fx = await TheaterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final unknownOut = await runner.runCapturing([
        'tdd',
        'theater',
        '999-no-such-feature',
        '--project',
        fx.root.path,
      ]);
      expect(unknownOut, contains('999-no-such-feature'));
      expect(
        unknownOut,
        contains('no feature directory at specs/999-no-such-feature'),
      );
      // The remediation guidance is part of the actionable-message
      // contract.
      expect(unknownOut, contains('ls specs/'));
      expect(unknownOut, contains('zfa tdd init 999-no-such-feature'));
      expect(exitCode, 1);

      // No cycle-log: still loads — every behavior renders pending, the
      // absence of evidence is not an error.
      final noLog = await TheaterFixture.create(withCycleLog: false);
      addTearDown(() => noLog.root.delete(recursive: true));
      final noLogOut = await runner.runCapturing([
        'tdd',
        'theater',
        noLog.featureName,
        '--project',
        noLog.root.path,
      ]);
      expect(
        lastLine(noLogOut),
        'theater: feature=${noLog.featureName} behaviors=3 cycles=0 '
        'receipts=2 result=non-tty',
      );

      // No registry: exit 1 naming the missing artifact + remediation.
      final noRegistry = await TheaterFixture.create(withRegistry: false);
      addTearDown(() => noRegistry.root.delete(recursive: true));
      final noRegistryOut = await runner.runCapturing([
        'tdd',
        'theater',
        noRegistry.featureName,
        '--project',
        noRegistry.root.path,
      ]);
      expect(
        noRegistryOut,
        contains(
          'no artifact registry at '
          'specs/${noRegistry.featureName}/tdd/artifacts.json',
        ),
      );
      expect(noRegistryOut, contains('zfa tdd gen <behavior-id> --feature'));
      expect(exitCode, 1);

      // An EXISTING but EMPTY registry: exit 1 naming the emptiness
      // (the theater never invents behaviors).
      final emptyRegistry = await TheaterFixture.create(withRegistry: false);
      addTearDown(() => emptyRegistry.root.delete(recursive: true));
      await File(
        p.join(emptyRegistry.featureDir, 'tdd', 'artifacts.json'),
      ).writeAsString(
        '{"feature": "${emptyRegistry.featureName}", "records": []}',
      );
      final emptyOut = await runner.runCapturing([
        'tdd',
        'theater',
        emptyRegistry.featureName,
        '--project',
        emptyRegistry.root.path,
      ]);
      expect(emptyOut, contains('carries no behavior records'));
      // The named artifact and the remediation command are part of the
      // message contract (same anchors as the missing-registry path).
      expect(
        emptyOut,
        contains(
          'specs/${emptyRegistry.featureName}/tdd/artifacts.json carries '
          'no behavior records',
        ),
      );
      expect(emptyOut, contains('zfa tdd gen <behavior-id> --feature'));
      expect(exitCode, 1);
    });
  });
}
