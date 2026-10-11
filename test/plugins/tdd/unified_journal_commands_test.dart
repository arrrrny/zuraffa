@Tags(['slow'])
// Unified TDD journal tests (spec 1113-unified-tdd-journal, issue
// #1113): `zfa tdd run` / `run-engine` / `run-skin` write the structured
// `tdd/journal.json` beside the receipts and cycle-log; `zfa tdd status`
// prints the journal's one-line verdict; `zfa tdd prove` computes the
// incremental delta (behaviors ungated since last prove); theater loads
// the journal through JournalReader. The commands run in-process through
// CliRunner.runCapturing over the fixture's scripted fake zfa binary
// (same conventions as two_cycle_run_commands_test.dart).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  // The issue's exit-criteria feature name: 004-login-ui.
  const feature = '004-login-ui';

  Future<String> run(String subcommand, {String? zfaBin}) async {
    final args = ['tdd', subcommand, feature, '--project', fx.root.path];
    // `status` / `prove` read the journal only — no step spawning, no
    // --zfa-bin.
    if (subcommand != 'status' && subcommand != 'prove') {
      args.addAll(['--zfa-bin', zfaBin ?? fx.fakeZfaBin]);
    }
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(args);
  }

  /// The lane-tagged test list: two CORE rows (U1, U2), two SKIN rows
  /// (W1, W2) and one BOTH row (A1) — the minimal split of issue #1008
  /// that exercises both lanes of the meta driver.
  Future<void> seedLanes() async {
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the acceptance behavior exercised by both lanes [both] | FR-001 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |
| U2 | the second core behavior [core] | FR-001 | PENDING |
| W1 | the first skin behavior [skin] | FR-002 | PENDING |
| W2 | the second skin behavior [skin] | FR-002 | PENDING |
''');
  }

  /// Register every behavior in the artifact registry (the per-behavior
  /// subject/test paths `prove` fingerprints) and write stable subject
  /// stubs — the pre-edit baseline every behavior's fingerprint covers.
  Future<void> seedRegistry() async {
    for (final id in const ['A1', 'U1', 'U2', 'W1', 'W2']) {
      await fx.registerBehavior(
        id: id,
        description: 'the $id behavior of $feature',
        sourceCriterion: id.startsWith('W') ? 'FR-002' : 'FR-001',
      );
      final subject = File(fx.subjectPathOf(id));
      await subject.parent.create(recursive: true);
      await subject.writeAsString(
        'library;\n\nint ${id.toLowerCase()}_value() => 42;\n',
      );
    }
  }

  String journalPath() => p.join(fx.featureDir, 'tdd', 'journal.json');

  String schemaPath() => p.join(fx.featureDir, 'tdd', 'journal.schema.json');

  Future<Map<String, dynamic>> readJournal() async =>
      jsonDecode(await File(journalPath()).readAsString())
          as Map<String, dynamic>;

  /// Structural validation of one journal entry against the spec-1113
  /// schema (the 9 required fields, the cycle/phase/gate_state enums,
  /// the refs triple) — the same rules `tdd/journal.schema.json`
  /// declares. Failures are collected into [failures] with [where]
  /// naming the entry under test.
  void validateEntry(
    Map<String, dynamic> entry,
    String where,
    List<String> failures,
  ) {
    void requireField(String name) {
      if (!entry.containsKey(name)) {
        failures.add('$where: missing required field "$name"');
      }
    }

    for (final name in const [
      'feature',
      'cycle',
      'phase',
      'started_at',
      'finished_at',
      'gate_state',
      'receipts',
      'violations',
      'refs',
    ]) {
      requireField(name);
    }
    if (entry['feature'] != feature) {
      failures.add('$where: feature is "${entry['feature']}", not $feature');
    }
    const cycles = {'engine', 'skin', 'meta'};
    if (!cycles.contains(entry['cycle'])) {
      failures.add('$where: cycle "${entry['cycle']}" outside $cycles');
    }
    const phases = {'gate', 'drive', 'aggregate', 'prove'};
    if (!phases.contains(entry['phase'])) {
      failures.add('$where: phase "${entry['phase']}" outside $phases');
    }
    const gateStates = {'green', 'red', 'preflight_red', 'not_assessed'};
    if (!gateStates.contains(entry['gate_state'])) {
      failures.add(
        '$where: gate_state "${entry['gate_state']}" outside $gateStates',
      );
    }
    for (final stamp in const ['started_at', 'finished_at']) {
      final raw = entry[stamp];
      if (raw is! String || DateTime.tryParse(raw) == null) {
        failures.add('$where: $stamp "$raw" is not an ISO-8601 timestamp');
      }
    }
    if (entry['receipts'] is! List) {
      failures.add('$where: receipts is not a list');
    }
    if (entry['violations'] is! List) {
      failures.add('$where: violations is not a list');
    }
    final refs = entry['refs'];
    if (refs is! Map<String, dynamic>) {
      failures.add('$where: refs is not an object');
    } else {
      for (final key in const [
        'engine_receipt',
        'skin_receipt',
        'contract_schema',
      ]) {
        if (!refs.containsKey(key)) {
          failures.add('$where: refs missing "$key"');
        }
      }
    }
  }

  setUp(() async {
    fx = await TddFixture.create(featureName: feature);
    await fx.writeFakeZfa();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('run writes the unified journal (FR-001/FR-003)', () {
    setUp(() async {
      await seedLanes();
      await seedRegistry();
    });

    test(
      'J-001: run writes tdd/journal.json (schema 1, feature, entries)',
      () async {
        final out = await run('run');

        expect(exitCode, 0, reason: out);
        expect(
          await File(journalPath()).exists(),
          isTrue,
          reason: 'zfa tdd run must write specs/$feature/tdd/journal.json',
        );
        final journal = await readJournal();
        expect(journal['schema'], 1);
        expect(journal['feature'], feature);
        expect((journal['entries'] as List?)?.length, greaterThan(0));
      },
    );

    test(
      'J-002: every entry is schema-valid (9 fields, enums, refs triple)',
      () async {
        final out = await run('run');

        expect(exitCode, 0, reason: out);
        final journal = await readJournal();
        final entries = journal['entries'] as List;
        expect(entries, isNotEmpty);
        final failures = <String>[];
        for (var i = 0; i < entries.length; i++) {
          validateEntry(
            entries[i] as Map<String, dynamic>,
            'entry[$i]',
            failures,
          );
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      },
    );

    test('J-003: the meta run journals engine, skin and meta entries with '
        'green gate_state and the receipt refs', () async {
      final out = await run('run');

      expect(exitCode, 0, reason: out);
      final journal = await readJournal();
      final entries = (journal['entries'] as List).cast<Map<String, dynamic>>();
      final engine = entries.where((e) => e['cycle'] == 'engine').toList();
      final skin = entries.where((e) => e['cycle'] == 'skin').toList();
      final meta = entries.where((e) => e['cycle'] == 'meta').toList();
      expect(engine, isNotEmpty, reason: 'no engine cycle entry');
      expect(skin, isNotEmpty, reason: 'no skin cycle entry');
      expect(meta, isNotEmpty, reason: 'no meta cycle entry');
      expect(engine.last['phase'], 'drive');
      expect(skin.last['phase'], 'drive');
      expect(meta.last['phase'], 'aggregate');
      expect(engine.last['gate_state'], 'green');
      expect(skin.last['gate_state'], 'green');
      expect(meta.last['gate_state'], 'green');
      final refs = meta.last['refs'] as Map<String, dynamic>;
      expect(refs['engine_receipt'], contains('04-engine-receipt.json'));
      expect(refs['skin_receipt'], contains('04-skin-receipt.json'));
      expect((meta.last['receipts'] as List).length, 2);
    });

    test('J-004: a fail-fast engine red journals the meta entry red with '
        'the stopped_at violation', () async {
      await fx.setStepOutcome('make', 'U2', 'not-certified-red');

      final out = await run('run');

      expect(exitCode, 1, reason: out);
      final journal = await readJournal();
      final meta = (journal['entries'] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['cycle'] == 'meta')
          .toList();
      expect(
        meta,
        isNotEmpty,
        reason: 'the fail-fast meta outcome must be journaled',
      );
      expect(meta.last['gate_state'], 'red');
      final violations = meta.last['violations'] as List;
      expect(
        violations.any((v) => '$v'.contains('U2:make')),
        isTrue,
        reason: 'the honest stop must be named as a violation',
      );
    });

    test('J-005: the cert-gate preflight refusal journals preflight_red '
        '(zero steps spawned)', () async {
      // A CORE entity with an on-disk mock but no certification: the
      // spec-1001/1110 gate refuses the meta run before any step.
      await File(fx.testListPath).writeAsString('''
# Test List: $feature

## Key Entities

| Entity | Fields |
| ------ | ------ |
| Login | id:String |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the first core behavior [core] | FR-001 | PENDING |
''');
      final mock = File(
        p.join(
          fx.root.path,
          'lib',
          'src',
          'data',
          'datasources',
          'login',
          'login_mock_datasource.dart',
        ),
      );
      await mock.parent.create(recursive: true);
      await mock.writeAsString('class LoginMockDataSource {}\n');

      final out = await run('run');

      expect(exitCode, 1, reason: out);
      expect(fx.stepInvocations(), isEmpty);
      final journal = await readJournal();
      final meta = (journal['entries'] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['cycle'] == 'meta')
          .toList();
      expect(
        meta,
        isNotEmpty,
        reason: 'the preflight refusal must be journaled',
      );
      expect(meta.last['phase'], 'gate');
      expect(meta.last['gate_state'], 'preflight_red');
      expect(
        (meta.last['violations'] as List).any((v) => '$v'.contains('Login')),
        isTrue,
        reason: 'the refused entity must be named',
      );
    });

    test(
      'J-006: run-engine and run-skin append their own cycle entries',
      () async {
        final engineOut = await run('run-engine');
        expect(exitCode, 0, reason: engineOut);
        exitCode = 0;
        final skinOut = await run('run-skin');
        expect(exitCode, 0, reason: skinOut);
        exitCode = 0;

        final journal = await readJournal();
        final entries = (journal['entries'] as List)
            .cast<Map<String, dynamic>>();
        final engine = entries.where((e) => e['cycle'] == 'engine').toList();
        final skin = entries.where((e) => e['cycle'] == 'skin').toList();
        expect(engine, isNotEmpty, reason: 'run-engine must journal its cycle');
        expect(engine.last['phase'], 'drive');
        expect(engine.last['gate_state'], 'green');
        expect(skin, isNotEmpty, reason: 'run-skin must journal its cycle');
        expect(skin.last['phase'], 'drive');
        expect(skin.last['gate_state'], 'green');
      },
    );

    test('J-007: journal.schema.json lands beside journal.json on first '
        'append and validates the written entries', () async {
      final out = await run('run');

      expect(exitCode, 0, reason: out);
      expect(
        await File(schemaPath()).exists(),
        isTrue,
        reason: 'the schema file must be written beside the journal',
      );
      final schema =
          jsonDecode(await File(schemaPath()).readAsString())
              as Map<String, dynamic>;
      expect(schema[r'$schema'], contains('2020-12'));
      // The written entries conform to the shipped schema document.
      final failures = <String>[];
      for (final entry in (await readJournal())['entries'] as List) {
        validateEntry(
          entry as Map<String, dynamic>,
          'entry[${(entry as Map)['cycle']}]',
          failures,
        );
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });

  group('status renders the journal verdict (FR-005)', () {
    setUp(() async {
      await seedLanes();
      await seedRegistry();
    });

    test('J-008: status prints the journal one-line verdict, exit 0 on '
        'green', () async {
      final runOut = await run('run');
      expect(exitCode, 0, reason: runOut);
      exitCode = 0;

      final out = await run('status');

      expect(exitCode, 0, reason: out);
      // The merged machine line keeps its shape (spec 1008 contract).
      expect(
        out,
        contains('status: feature=$feature engine=green skin=green'),
        reason: out,
      );
      // The journal's one-line verdict (issue #1113's shape):
      // <feature> | engine ✅ d/t | skin ✅ d/t | mocks c/t | n
      // violations.
      expect(out, contains('$feature | '), reason: out);
      expect(out, contains('engine ✅ 3/3'), reason: out);
      expect(out, contains('skin ✅ 3/3'), reason: out);
      expect(out, contains('mocks 0/0 certified'), reason: out);
      expect(out, contains('0 violations'), reason: out);
    });
  });

  group('prove computes the incremental delta (FR-004)', () {
    setUp(() async {
      await seedLanes();
      await seedRegistry();
    });

    test('J-009: baseline prove on a green feature is clean (all gated, '
        'exit 0) and journals a prove entry', () async {
      final runOut = await run('run');
      expect(exitCode, 0, reason: runOut);
      exitCode = 0;

      final out = await run('prove');

      expect(exitCode, 0, reason: out);
      expect(out, contains('prove: feature=$feature'), reason: out);
      expect(out, contains('ungated=0'), reason: out);
      final journal = await readJournal();
      final prove = (journal['entries'] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['phase'] == 'prove')
          .toList();
      expect(prove, isNotEmpty, reason: 'prove must journal its delta');
      expect(prove.last['cycle'], 'meta');
      expect(prove.last['gate_state'], 'green');
    });

    test('J-010: after editing ONE skin view, prove reports only that '
        'behavior ungated (incremental, exit 1)', () async {
      final runOut = await run('run');
      expect(exitCode, 0, reason: runOut);
      exitCode = 0;
      final baselineOut = await run('prove');
      expect(exitCode, 0, reason: baselineOut);
      exitCode = 0;

      // Edit one skin view: W1's subject changes, everything else is
      // untouched.
      await File(fx.subjectPathOf('W1')).writeAsString(
        'library;\n\nint w1_value() => 43; // hand-edited skin view\n',
      );

      final out = await run('prove');

      expect(exitCode, 1, reason: out);
      expect(out, contains('ungated=1'), reason: out);
      expect(out, contains('W1'), reason: out);
      expect(out, isNot(contains('ungated: U1')), reason: out);
      expect(out, isNot(contains('ungated: U2')), reason: out);
      expect(out, isNot(contains('ungated: W2')), reason: out);
      expect(out, isNot(contains('ungated: A1')), reason: out);
      // The prove entry journals the delta.
      final journal = await readJournal();
      final prove = (journal['entries'] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['phase'] == 'prove')
          .toList();
      expect(prove.last['gate_state'], 'red');
    });

    test('J-011: prove on a feature with no green evidence reports every '
        'behavior ungated (not_assessed)', () async {
      final out = await run('prove');

      expect(exitCode, 1, reason: out);
      expect(out, contains('ungated=5'), reason: out);
      final journal = await readJournal();
      final prove = (journal['entries'] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['phase'] == 'prove')
          .toList();
      expect(prove.last['gate_state'], 'not_assessed');
    });

    test('J-012: prove refuses an unknown feature dir (misfire)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'prove',
        '999-no-such-feature',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('999-no-such-feature'), reason: out);
    });
  });
}
