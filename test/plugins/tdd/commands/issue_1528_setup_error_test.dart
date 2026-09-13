// Issue #1528 — fresh-project first run stops with classification=unresolved
// on a missing TDD profile: a SETUP condition misclassified, and the
// idempotent fix (`tdd init`) not auto-applied.
//
// RED evidence (pre-fix master):
//   * U-1528-1: `zfa tdd verify-red B-001` on a profile-less fixture ends
//     `classification=unresolved` — the same verdict the classifier uses for
//     "the runner could not classify this failure".
//   * U-1528-2: `verify-red --all` reports batch `classification=unresolved`.
//   * U-1528-4: `zfa tdd run` drives step A1 gen, then stops at
//     A1:verify-red on the missing profile — the run never preflights the
//     baseline its own error message prescribes (`zfa tdd init`).
//   * U-1528-5: `zfa tdd gen` does not ensure the baseline either.
//
// Contract pinned here (remediation, spec 1528):
//   1. verify-red (single + batch lanes): missing profile → fail CLOSED with
//      the distinct machine-readable class `setup-error` + verdict receipt +
//      `--> fix:` remediation naming `zfa tdd init` — NEVER `unresolved`;
//      NO writes (the FR-008 read-only contract is preserved — verify-red
//      does not auto-init). Resolution errors keep `unresolved` and their
//      ordering BEFORE the setup probe (U18/sc-004 A13 pinned).
//   2. `zfa tdd run` / `zfa tdd gen` entries preflight the baseline: missing
//      profile → auto-run the idempotent init sequence (created artifacts
//      logged), loop proceeds; init misfire → fail closed (journaled
//      preflight_red for run, refusal verdict for gen), zero steps.
//   3. Profile present → silent no-op: byte-identical pre-#1528 behavior.
//
// Test tiers: FAST (the verify-red/gen classification groups spawn no test
// processes); the run-driver group carries `slow` + `integration` (the
// fixture pub-gets; the fake zfa drives the loop).

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  tearDown(() => exitCode = 0);

  group('unit — U-1528-1: verify-red missing profile fails CLOSED as '
      'setup-error (single lane)', () {
    setUp(() async {
      fx = await TddFixture.create(writeProfile: false);
      await fx.registerBehavior(id: 'B-001', description: 'a behavior');
    });

    tearDown(() => fx.dispose());

    test('classification=setup-error, never unresolved; exit non-zero; '
        'no evidence; remediation names zfa tdd init', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        'B-001',
      ]);

      expect(
        out,
        contains(
          'verify-red: behavior=B-001 classification=setup-error '
          'certified=false feature=${fx.featureName}',
        ),
        reason: 'out:\n$out',
      );
      expect(out, isNot(contains('classification=unresolved')));
      expect(out.toLowerCase(), contains('tdd-profile.md'));
      expect(out, contains('zfa tdd init'));
      expect(exitCode, isNot(0));
      // No evidence appended; no test/ or lib/ writes (FR-008 preserved —
      // verify-red must NOT auto-init).
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
      expect(
        File(
          p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
        ).existsSync(),
        isFalse,
        reason:
            'verify-red fails closed; the baseline self-heal belongs to '
            'the run/gen entries',
      );
    });

    test('--json closes with a verdict receipt carrying exit_class '
        'setup-error', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        '--json',
        'B-001',
      ]);
      final last = out.trim().split('\n').last;
      final envelope =
          jsonDecode(last) as Map<String, dynamic>; // the verdict receipt
      expect(envelope['command'], 'verify-red');
      expect(envelope['exit_class'], 'setup-error');
      expect(envelope['outcome'], isNot('pass'));
    });
  });

  group('unit — U-1528-2: verify-red --all missing profile (batch lane)', () {
    setUp(() async {
      fx = await TddFixture.create(writeProfile: false);
      await fx.registerBehavior(id: 'B-001', description: 'a behavior');
    });

    tearDown(() => fx.dispose());

    test('batch + per-behavior summaries classify setup-error', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        '--all',
      ]);

      expect(
        out,
        contains(
          'verify-red: batch=true behaviors=1 certified=0 '
          'classification=setup-error feature=all',
        ),
        reason: 'out:\n$out',
      );
      expect(
        out,
        contains('classification=setup-error'),
        reason: 'the per-behavior summary classifies setup-error too',
      );
      expect(exitCode, isNot(0));
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    });

    test('empty targets keep the honest nothing-to-certify exit 0 '
        '(classification=batch) even without a profile', () async {
      // A fresh fixture with no registry records at all.
      final empty = await TddFixture.create(writeProfile: false);
      try {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          empty.root.path,
          '--all',
        ]);
        expect(out, contains('classification=batch'));
        expect(exitCode, 0);
      } finally {
        empty.dispose();
      }
    });
  });

  group('unit — U-1528-3: ordering + vocabulary invariants', () {
    test('unknown id with NO profile still resolves FIRST → unresolved '
        '(a caller error is not a setup condition)', () async {
      final fx2 = await TddFixture.create(writeProfile: false);
      try {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx2.root.path,
          'B-999',
        ]);
        expect(out, contains('unknown behavior id'));
        expect(
          out,
          contains(
            'verify-red: behavior=B-999 classification=unresolved '
            'certified=false',
          ),
        );
        expect(exitCode, isNot(0));
      } finally {
        fx2.dispose();
      }
    });

    test('a valid-profile rejection matrix is unchanged: unexpected-green '
        'stays unexpected-green', () async {
      fx = await TddFixture.create(); // profile PRESENT
      try {
        await fx.registerBehavior(
          id: 'B-001',
          description: 'a behavior',
          testContent: TddFixture.greenTest('a behavior'),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          'B-001',
        ]);
        expect(out, contains('classification=unexpected-green'));
        expect(out, isNot(contains('classification=setup-error')));
      } finally {
        fx.dispose();
      }
    });
  });

  group('slow — U-1528-4: run entry preflights the baseline', () {
    setUp(() async {
      fx = await TddFixture.create(
        featureName: '090-fresh-run',
        writeProfile: false,
      );
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
    });

    tearDown(() => fx.dispose());

    Future<String> drive({List<String> extraArgs = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'run',
        '090-fresh-run',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
        ...extraArgs,
      ]);
    }

    test(
      'missing profile → auto idempotent init (artifacts logged) and the '
      'loop drives its first step — no unresolved anywhere',
      tags: ['integration'],
      () async {
        final out = await drive();

        expect(
          File(
            p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
          ).existsSync(),
          isTrue,
          reason: 'the entry preflight recreated the profile\n$out',
        );
        expect(
          File(
            p.join(fx.root.path, 'test', 'bootstrap_smoke_test.dart'),
          ).existsSync(),
          isTrue,
          reason: 'the init sequence created the day-zero smoke test',
        );
        expect(out, contains('zfa tdd run: preflight'));
        expect(out.toLowerCase(), contains('tdd-profile.md'));
        expect(out, isNot(contains('classification=unresolved')));
        expect(
          fx.stepInvocations(),
          isNotEmpty,
          reason: 'the loop proceeded past the entry\n$out',
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test(
      'init misfire → fail closed BEFORE any step: journaled preflight_red, '
      'result=setup-error summary, exit 1, zero spawns',
      tags: ['integration'],
      () async {
        // Corrupt the pubspec so the init sequence's patchers misfire.
        final pubspec = File(p.join(fx.root.path, 'pubspec.yaml'));
        // A LEADING TAB is illegal YAML indentation — loadYaml throws
        // YamlException, the baseline init misfires, the run fail-closes.
        pubspec.writeAsStringSync('\tbroken: yaml: [\n');

        final out = await drive();

        expect(
          fx.stepInvocations(),
          isEmpty,
          reason: 'no step may spawn on a broken baseline\n$out',
        );
        expect(
          out,
          contains('run: feature=090-fresh-run result=setup-error'),
          reason: 'out:\n$out',
        );
        expect(exitCode, 1);
        expect(
          File(
            p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
          ).existsSync(),
          isFalse,
          reason: 'the baseline was not ensured — the refusal is honest',
        );
        // The refusal is journaled preflight_red with the failure named.
        final journal = File(
          p.join(fx.featureDir, 'tdd', 'journal.json'),
        ).readAsStringSync();
        expect(journal, contains('preflight_red'));
        expect(journal.toLowerCase(), contains('pubspec'));
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  group('slow — U-1528-5: gen entry preflights the baseline', () {
    setUp(() async {
      fx = await TddFixture.create(writeProfile: false);
      await fx.seedTestList([
        (
          id: 'B-001',
          description: 'first behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
    });

    tearDown(() => fx.dispose());

    test(
      'missing profile → baseline ensured before the flow; artifacts logged',
      tags: ['integration'],
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          '--project',
          fx.root.path,
          'B-001',
        ]);

        expect(
          File(
            p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
          ).existsSync(),
          isTrue,
          reason: 'the gen entry recreated the profile\n$out',
        );
        expect(out, contains('zfa tdd gen: preflight'));
        expect(exitCode, 0, reason: 'out:\n$out');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test(
      'init misfire → fail-closed refusal, exit 1, verdict setup-error',
      tags: ['integration'],
      () async {
        final pubspec = File(p.join(fx.root.path, 'pubspec.yaml'));
        // A LEADING TAB is illegal YAML indentation — loadYaml throws
        // YamlException, the baseline init misfires, the gen fail-closes.
        pubspec.writeAsStringSync('\tbroken: yaml: [\n');

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'gen',
          '--project',
          fx.root.path,
          '--json',
          'B-001',
        ]);

        expect(exitCode, isNot(0));
        final last = out.trim().split('\n').last;
        final envelope = jsonDecode(last) as Map<String, dynamic>;
        expect(envelope['command'], 'gen');
        expect(envelope['exit_class'], 'setup-error');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  group('unit — U-1528-6: no-op guarantee (profile present)', () {
    test('preflight prints nothing and writes nothing when the profile '
        'exists (verify-red path unchanged)', () async {
      fx = await TddFixture.create(); // profile PRESENT
      try {
        await fx.registerBehavior(id: 'B-001', description: 'a behavior');
        final before = File(
          p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
        ).readAsStringSync();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          'B-001',
        ]);
        expect(out, isNot(contains('preflight')));
        final after = File(
          p.join(fx.root.path, '.specify', 'memory', 'tdd-profile.md'),
        ).readAsStringSync();
        expect(after, before, reason: 'the profile was not touched');
        expect(exitCode, 0, reason: 'the honest red certifies as before');
      } finally {
        fx.dispose();
      }
    });
  });
}
