@Tags(['slow', 'integration'])
// Issue #1660 — a skipped refactor pass is indistinguishable from an
// executed one on stdout — print the skip note.
//
// The #1624 build-relevance gate records a skipped `build` pass as a
// synthetic action (`skipped: true`, exit 0, no changes, the gate's full
// `refactorBuildSkippedNote` as `output`). `refactor_command.dart`'s pass
// loop printed only `pass/command/exit/changed` — the exact same shape an
// executed no-op pass produces — so an operator (or an agent measuring the
// #1624 economics) cannot tell whether the heaviest pass ran, and the
// gate's honest-skip evidence (the #1637 config-digest clearance, the
// "a DELETED source is invisible to this gate" caveat) never reaches the
// human.
//
// Remediation under test: the pass loop names the skip on the pass line
// itself (`— SKIPPED (build-relevance gate)`) and surfaces the gate's full
// note as a `note:` line; executed passes print byte-identically to
// before; the cycle-log entry mirrors one `note:` line per skipped pass.
//
// Driver-level tests: the command runs in-process through CliRunner; the
// #1624 skip is produced by the REAL gate against a fixture whose
// completed-build marker (`.dart_tool/build/asset_graph.json`) is strictly
// newer than every source/config file the gate walks — the gate's `newer`
// set is empty and it returns the exact `refactorBuildSkippedNote` the
// issue describes. No gate semantics are touched here (hard constraint).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late String fakeZfa;

  setUp(() async {
    fx = await TddFixture.create();
    fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  List<String> refactorArgs() => [
    'tdd',
    'refactor',
    '--project',
    fx.root.path,
    '--zfa-bin',
    fakeZfa,
  ];

  /// A completed-build marker strictly NEWER than every source/config file
  /// the #1624 gate walks (seeded lib/test are older; the fixture's pub
  /// get ran in setUp): the gate's `newer` set is empty and it returns the
  /// incremental `refactorBuildSkippedNote` — the issue's exact skip.
  Future<void> seedCompletedBuildNewerThanTree() async {
    await fx.seedAlreadyCleanLib();
    final marker = File(
      p.join(fx.root.path, '.dart_tool', 'build', 'asset_graph.json'),
    );
    await marker.create(recursive: true);
    await marker.writeAsString('{}');
    marker.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
  }

  test('U-1660-1: a build pass skipped by the #1624 gate prints the SKIPPED '
      'marker + the gate note on stdout (SC-1/SC-2)', () async {
    await seedCompletedBuildNewerThanTree();

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(refactorArgs());

    expect(exitCode, 0, reason: out);

    // The pass line itself names the skip — the issue's marker.
    expect(
      out,
      contains('pass: build — SKIPPED (build-relevance gate)'),
      reason: out,
    );
    // The gate's full note is surfaced as a note: line — its distinctive
    // opening names the pass, and the honest-skip evidence rides along
    // (the #1637 config-digest clearance + the deleted-source caveat).
    expect(out, contains('note: refactor build pass skipped:'), reason: out);
    expect(out, contains('issue #1637'), reason: out);
    expect(out, contains('DELETED'), reason: out);
    // The synthetic action stays honest: exit 0, nothing changed. Anchored
    // to the skip block — a bare `contains('exit: 0')` would also match the
    // preflight's `   preflight exit: 0` line, so the assertion would pass
    // even if the action's own exit line were dropped or corrupted.
    expect(
      out,
      matches(RegExp('pass: build — SKIPPED[\\s\\S]*?     exit: 0')),
      reason: out,
    );
    expect(out, contains('changed: (none)'), reason: out);

    // The executed passes keep the plain shape (SC-3) — and the marker is
    // bound to the skip, never printed for a real spawn.
    expect(out, contains('   pass: format\n'), reason: out);
    expect(out, contains('   pass: fix\n'), reason: out);
    expect(out, isNot(contains('pass: format — SKIPPED')), reason: out);
    expect(out, isNot(contains('pass: fix — SKIPPED')), reason: out);
  });

  test('U-1660-2: an executed build pass prints the legacy shape — no '
      'SKIPPED marker, no gate note (SC-3, no regression)', () async {
    await fx.seedAlreadyCleanLib();
    // Marker backdated one hour: every config file the gate tiers
    // (pubspec.lock, package_config.json) is newer, and no #1637 config
    // baseline exists yet — the gate's documented fail-safe direction is
    // RUN (`_loadConfigBaseline` → null → record + run). Deterministic —
    // no mtime-granularity race decides this test.
    final marker = File(
      p.join(fx.root.path, '.dart_tool', 'build', 'asset_graph.json'),
    );
    await marker.create(recursive: true);
    await marker.writeAsString('{}');
    marker.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 1)),
    );

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(refactorArgs());

    expect(exitCode, 0, reason: out);

    // The executed pass prints the plain header (the issue's exact shape)
    // with its command and exit code — never the skip evidence.
    expect(out, contains('   pass: build\n'), reason: out);
    expect(out, contains('command: $fakeZfa build'), reason: out);
    expect(out, isNot(contains('— SKIPPED')), reason: out);
    expect(
      out,
      isNot(contains('note: refactor build pass skipped')),
      reason: out,
    );

    // Proof of execution: the fake zfa was really spawned for the build —
    // the marker never lies about which passes ran.
    final log = await fx.readFakeZfaLog();
    expect(log.join(' '), contains('build'), reason: 'fake zfa argv: $log');
  });

  test('U-1660-3: the refactor cycle-log entry mirrors one note: line '
      'carrying the gate note (SC-4)', () async {
    await seedCompletedBuildNewerThanTree();

    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(refactorArgs());

    expect(exitCode, 0, reason: out);

    final raw = await File(fx.cycleLogPath).readAsString();
    final entry = raw
        .split('\n## ')
        .firstWhere((s) => s.contains('- kind: refactor'));
    // One mirrored note: line inside the entry's output block — the same
    // evidence stdout carries, now auditable in the cycle log too.
    expect(entry, contains('note: refactor build pass skipped:'), reason: raw);
  });
}
