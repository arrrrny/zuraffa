// Unit behaviors for the unified TDD journal service (spec
// 1113-unified-tdd-journal, issue #1113): the schema document, the
// writer's append/atomicity/schema-emit contract, the reader's one
// canonical stream (entries, refs-followed receipts, cycle-log content,
// green evidence, behaviors, verdict), and the prove fingerprint
// primitive. No step spawning — everything seeds files directly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/journal.dart';

import '../../../helpers/project_root.dart';

void main() {
  late Directory tmp;
  late String featureDir;
  const feature = '004-login-ui';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('journal_unit_');
    featureDir = p.join(tmp.path, 'specs', feature);
    Directory(featureDir).createSync(recursive: true);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  JournalEntry entry({
    String cycle = 'engine',
    String phase = 'drive',
    String gateState = 'green',
    List<String> violations = const [],
    String? engineReceipt = 'tdd/04-engine-receipt.json',
    String? skinReceipt,
    String? contractSchema,
    Map<String, int>? mocks,
    Map<String, Map<String, String?>>? fingerprints,
  }) => JournalEntry(
    feature: feature,
    cycle: cycle,
    phase: phase,
    startedAt: '2026-09-06T00:00:00.000Z',
    finishedAt: '2026-09-06T00:01:00.000Z',
    gateState: gateState,
    receipts: const [],
    violations: violations,
    engineReceipt: engineReceipt,
    skinReceipt: skinReceipt,
    contractSchema: contractSchema,
    mocks: mocks,
    fingerprints: fingerprints,
  );

  group('JournalSchema (U1)', () {
    test('U1.1: the document is a draft 2020-12 schema over the model', () {
      final doc = JournalSchema.document();
      expect(doc[r'$schema'], 'https://json-schema.org/draft/2020-12/schema');
      expect(doc['required'], containsAll(['schema', 'feature', 'entries']));
      final items =
          (doc['properties']['entries'] as Map)['items']
              as Map<String, dynamic>;
      expect(items['required'], containsAll(JournalEntryFields.required));
      // The enums come from the model constants — no drift possible.
      final props = items['properties'] as Map<String, dynamic>;
      expect((props['cycle'] as Map)['enum'], journalCycles.toList());
      expect((props['phase'] as Map)['enum'], journalPhases.toList());
      expect((props['gate_state'] as Map)['enum'], journalGateStates.toList());
      final refs = props['refs'] as Map<String, dynamic>;
      expect((refs['properties'] as Map).keys.toSet(), {
        'engine_receipt',
        'skin_receipt',
        'contract_schema',
      });
    });

    test('U1.2: validateEntry accepts the canonical entry', () {
      expect(JournalSchema.validateEntry(entry().toJson()), isEmpty);
    });

    test('U1.3: validateEntry rejects missing fields, bad enums, bad refs', () {
      final bad = entry().toJson()..remove('gate_state');
      expect(JournalSchema.validateEntry(bad), isNotEmpty);

      final badEnum = entry(gateState: 'yellow').toJson();
      expect(JournalSchema.validateEntry(badEnum), isNotEmpty);

      final badCycle = entry(cycle: 'meta-phase').toJson();
      expect(JournalSchema.validateEntry(badCycle), isNotEmpty);

      final badPhase = entry(phase: 'later').toJson();
      expect(JournalSchema.validateEntry(badPhase), isNotEmpty);

      final badRefs = entry().toJson();
      (badRefs['refs'] as Map).remove('engine_receipt');
      expect(JournalSchema.validateEntry(badRefs), isNotEmpty);

      final badStamp = entry().toJson()..['started_at'] = 'not-a-timestamp';
      expect(JournalSchema.validateEntry(badStamp), isNotEmpty);
    });
  });

  group('JournalWriter (U2)', () {
    test(
      'U2.1: first append writes journal.json + journal.schema.json',
      () async {
        await JournalWriter(featureDir).append(entry());

        final journalFile = File(p.join(featureDir, 'tdd', 'journal.json'));
        final schemaFile = File(
          p.join(featureDir, 'tdd', 'journal.schema.json'),
        );
        expect(journalFile.existsSync(), isTrue);
        expect(schemaFile.existsSync(), isTrue);
        final doc =
            jsonDecode(journalFile.readAsStringSync()) as Map<String, dynamic>;
        expect(doc['schema'], 1);
        expect(doc['feature'], feature);
        expect((doc['entries'] as List), hasLength(1));
        final schema =
            jsonDecode(schemaFile.readAsStringSync()) as Map<String, dynamic>;
        expect(schema[r'$schema'], contains('2020-12'));
      },
    );

    test('U2.2: appends preserve prior entries, no tmp left behind', () async {
      final writer = JournalWriter(featureDir);
      await writer.append(entry(cycle: 'engine'));
      await writer.append(entry(cycle: 'skin'));
      await writer.append(entry(cycle: 'meta', phase: 'aggregate'));

      final journalFile = File(p.join(featureDir, 'tdd', 'journal.json'));
      final doc =
          jsonDecode(journalFile.readAsStringSync()) as Map<String, dynamic>;
      expect(
        (doc['entries'] as List).map((e) => (e as Map)['cycle']).toList(),
        ['engine', 'skin', 'meta'],
      );
      // Atomic writes leave no .tmp sibling.
      expect(
        Directory(p.join(featureDir, 'tdd'))
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where((n) => n.endsWith('.tmp')),
        isEmpty,
      );
    });

    test('U2.3: the schema file is written once, not per append', () async {
      final writer = JournalWriter(featureDir);
      await writer.append(entry());
      final schemaFile = File(p.join(featureDir, 'tdd', 'journal.schema.json'));
      final first = schemaFile.readAsStringSync();
      await writer.append(entry(cycle: 'skin'));
      expect(schemaFile.readAsStringSync(), first);
    });

    test('U2.4: refs resolve only when the artifact exists', () async {
      final writer = JournalWriter(featureDir);
      // Nothing on disk: all refs null (honest, not wishful).
      var refs = await writer.resolveRefs();
      expect(refs.engine, isNull);
      expect(refs.skin, isNull);
      expect(refs.contract, isNull);

      await File(
        p.join(featureDir, 'tdd', '04-engine-receipt.json'),
      ).create(recursive: true);
      refs = await writer.resolveRefs();
      expect(refs.engine, 'tdd/04-engine-receipt.json');
      expect(refs.skin, isNull);
    });

    test(
      'U2.5: the journal write is fsync\'d before the rename (bug #1469)',
      () async {
        // Bug #828 gave every committed TDD store the crash-safe write
        // discipline — writeAsString → flushToDisk(tmp) → rename — but
        // missed journal.json (bug #1469): a power loss between the
        // writeAsString and the rename could leave a truncated journal,
        // breaking the unified audit trail.
        //
        // flushToDisk is a top-level function over dart:io files and is
        // not injectable, so the discipline is enforced syntactically on
        // JournalWriter.append — the same source-level-guard approach the
        // suite already uses (e.g. issue_1173_engine_purity_test).
        final root = await findProjectRoot();
        final source = File(
          p.join(
            root,
            'lib',
            'src',
            'plugins',
            'tdd',
            'services',
            'journal.dart',
          ),
        ).readAsStringSync();
        final unit = parseString(content: source, throwIfDiagnostics: false);

        final writer = unit.unit.declarations
            .whereType<ClassDeclaration>()
            .firstWhere((c) => c.namePart.typeName.lexeme == 'JournalWriter');
        final append = writer.body.members
            .whereType<MethodDeclaration>()
            .firstWhere((m) => m.name.lexeme == 'append');

        final invocations = <MethodInvocation>[];
        final tmpDecls = <VariableDeclaration>[];
        append.accept(_JournalWriteCollector(invocations, tmpDecls));

        // The journal write's tmp file is declared from file.path — never
        // the schema write's tmp ('${schemaFile.path}.tmp').
        final journalTmps = tmpDecls
            .where(
              (v) =>
                  v.initializer!.toString().contains("file.path}.tmp'") &&
                  !v.initializer!.toString().contains('schemaFile'),
            )
            .toList();
        expect(journalTmps, hasLength(1));

        final writes = invocations
            .where((i) => i.methodName.name == 'writeAsString')
            .toList();
        final flushes = invocations
            .where((i) => i.methodName.name == 'flushToDisk')
            .toList();
        final renames = invocations
            .where((i) => i.methodName.name == 'rename')
            .toList();

        // RED discriminator: append must fsync the tmp file at all.
        expect(
          flushes,
          isNotEmpty,
          reason:
              'JournalWriter.append never fsync\'s the tmp file before the '
              'rename — the #828 crash-safe write discipline '
              '(writeAsString → flushToDisk → rename) is missing for '
              'journal.json (bug #1469).',
        );

        // The journal write is the final writeAsString/rename pair in
        // append() (the schema write precedes it), and it renames over
        // journal.json (file.path) — not the schema file.
        final write = writes.last;
        final rename = renames.last;
        expect(rename.target!.toString(), 'tmp');
        expect(rename.argumentList.arguments.single.toString(), 'file.path');
        expect(write.offset, greaterThan(journalTmps.single.offset));

        // Exactly one flushToDisk(tmp) sits between the journal
        // writeAsString and its rename, targeting the journal tmp.
        final inBetween = flushes
            .where((f) => write.offset < f.offset && f.offset < rename.offset)
            .toList();
        expect(inBetween, hasLength(1));
        // Top-level call — no receiver; the invoked name is flushToDisk.
        expect(inBetween.single.methodName.name, 'flushToDisk');
        expect(
          inBetween.single.argumentList.arguments.single.toString(),
          'tmp',
        );
      },
    );
  });

  group('JournalReader (U3)', () {
    test(
      'U3.1: absent journal is honest pending state, never an error',
      () async {
        final journal = await const JournalReader().read(
          feature: feature,
          projectRoot: tmp.path,
        );
        expect(journal.journalPresent, isFalse);
        expect(journal.entries, isEmpty);
        expect(journal.verdict.engineVerdict, 'absent');
        expect(journal.verdict.skinVerdict, 'absent');
      },
    );

    test('U3.2: reads entries and follows refs to the receipts', () async {
      await File(p.join(featureDir, 'tdd', '04-engine-receipt.json'))
          .create(recursive: true)
          .then(
            (f) => f.writeAsString(
              jsonEncode({
                'schema': 1,
                'feature': feature,
                'lane': 'engine',
                'verdict': 'green',
                'result': 'complete',
                'counts': {
                  'total': 3,
                  'pending': 0,
                  'red': 0,
                  'green': 0,
                  'done': 3,
                },
              }),
            ),
          );
      await JournalWriter(featureDir).append(
        entry().copyWith(
          engineReceipt: 'tdd/04-engine-receipt.json',
          mocks: {'total': 6, 'certified': 6},
        ),
      );

      final journal = await const JournalReader().read(
        feature: feature,
        projectRoot: tmp.path,
      );
      expect(journal.journalPresent, isTrue);
      expect(journal.entries, hasLength(1));
      expect(journal.receipts['engine']?['verdict'], 'green');
      expect(journal.verdict.engineVerdict, 'green');
      expect(journal.verdict.engineDone, 3);
      expect(journal.verdict.engineTotal, 3);
      // Mocks ride the engine entry.
      expect(journal.verdict.mockCertified, 6);
      expect(journal.verdict.mockTotal, 6);
      expect(journal.verdict.oneLine, contains('mocks 6/6 certified'));
    });

    test(
      'U3.3: a corrupt journal is an honest error with a recovery path',
      () async {
        final tdd = Directory(p.join(featureDir, 'tdd'))
          ..createSync(recursive: true);
        await File(p.join(tdd.path, 'journal.json')).writeAsString('{not json');
        await expectLater(
          const JournalReader().read(feature: feature, projectRoot: tmp.path),
          throwsA(
            isA<JournalException>().having(
              (e) => e.message,
              'message',
              contains('corrupt journal'),
            ),
          ),
        );
      },
    );

    test(
      'U3.4: a legacy #828 transaction marker reads as an empty journal',
      () async {
        final tdd = Directory(p.join(featureDir, 'tdd'))
          ..createSync(recursive: true);
        await File(p.join(tdd.path, 'journal.json')).writeAsString(
          jsonEncode({
            'schema': 1,
            'feature': feature,
            'behavior': 'B-001',
            'step': 'make',
            'pid': 1,
            'at': '2026-09-01T00:00:00.000Z',
            'status': 'pending',
          }),
        );
        final journal = await const JournalReader().read(
          feature: feature,
          projectRoot: tmp.path,
        );
        expect(journal.journalPresent, isTrue);
        expect(journal.entries, isEmpty);
      },
    );

    test(
      'U3.5: green evidence and behaviors come from the shared sources',
      () async {
        final tdd = Directory(p.join(featureDir, 'tdd'))
          ..createSync(recursive: true);
        await File(p.join(tdd.path, 'cycle-log.md')).writeAsString('''
# Cycle Log

## Cycle: W1 (green)

- behavior: W1
- kind: green
- criterion: FR-002
- test: test/login/w1_test.dart
- exit: 0
- at: 2026-09-05T00:00:00.000Z

''');
        await File(p.join(tdd.path, 'artifacts.json')).writeAsString(
          jsonEncode({
            'feature': feature,
            'records': [
              {
                'behavior_id': 'W1',
                'feature': feature,
                'source_criterion': 'FR-002',
                'test_path': 'test/login/w1_test.dart',
                'subject_path': 'lib/src/login/w1_subject.dart',
                'runnable_test_name': 'test/login/w1_test.dart::W1::desc',
                'test_ownership': 'created',
                'subject_ownership': 'created',
                'created_at': '2026-09-05T00:00:00.000Z',
              },
            ],
          }),
        );

        final journal = await const JournalReader().read(
          feature: feature,
          projectRoot: tmp.path,
        );
        expect(journal.greenEvidence['W1'], '2026-09-05T00:00:00.000Z');
        expect(journal.cycleLog, contains('## Cycle: W1 (green)'));
        expect(journal.behaviors, hasLength(1));
        expect(journal.behaviors.first.id, 'W1');
        expect(
          journal.behaviors.first.subjectPath,
          'lib/src/login/w1_subject.dart',
        );
      },
    );

    test('U3.6: skin.v1 receipts count conformance and platforms', () async {
      await File(p.join(featureDir, 'tdd', '04-skin-receipt.json'))
          .create(recursive: true)
          .then(
            (f) => f.writeAsString(
              jsonEncode({
                'schema': 'skin.v1',
                'feature': feature,
                'command': 'zfa tdd run-skin $feature',
                'behaviors': [
                  {
                    'behavior': 'W1',
                    'conformance': true,
                    'test': 'test/login/w1_test.dart',
                    'subject': 'lib/src/login/w1_subject.dart',
                    'platform_slot_fills': ['mobile', 'ios'],
                  },
                  {
                    'behavior': 'W2',
                    'conformance': false,
                    'test': 'test/login/w2_test.dart',
                    'subject': 'lib/src/login/w2_subject.dart',
                    'platform_slot_fills': ['mobile'],
                  },
                ],
                'platform_slot_fills': ['mobile', 'ios', 'mobile'],
                'hand_edits': [],
                'skin_event_trace_digest': 'x',
                'red_witness': true,
                'generated_at': '2026-09-06T00:00:00.000Z',
              }),
            ),
          );

      final journal = await const JournalReader().read(
        feature: feature,
        projectRoot: tmp.path,
      );
      expect(journal.verdict.skinVerdict, 'red'); // 1 of 2 conformed
      expect(journal.verdict.skinDone, 1); // the conformed row
      expect(journal.verdict.skinTotal, 2);
      expect(journal.verdict.platforms, 2); // distinct slots
    });

    test('U3.7: violations sum across entries', () async {
      final writer = JournalWriter(featureDir);
      await writer.append(entry(violations: ['stopped_at=U1:make']));
      await writer.append(
        entry(cycle: 'meta', phase: 'aggregate', violations: ['a', 'b']),
      );
      final journal = await const JournalReader().read(
        feature: feature,
        projectRoot: tmp.path,
      );
      expect(journal.verdict.violations, 3);
      expect(journal.verdict.oneLine, contains('3 violations'));
    });

    test('U3.8: lastProve/lastEngineCycle/lastMeta accessors', () async {
      final writer = JournalWriter(featureDir);
      await writer.append(entry());
      await writer.append(entry(cycle: 'skin'));
      await writer.append(
        entry(cycle: 'meta', phase: 'aggregate', gateState: 'red'),
      );
      await writer.append(
        entry(
          cycle: 'meta',
          phase: 'prove',
          gateState: 'green',
          fingerprints: {
            'W1': {'subject': 'abc', 'test': null},
          },
        ),
      );

      final journal = await const JournalReader().read(
        feature: feature,
        projectRoot: tmp.path,
      );
      expect(journal.lastProve?.phase, 'prove');
      expect(journal.lastProve?.fingerprints?['W1']?['subject'], 'abc');
      expect(journal.lastEngineCycle?.cycle, 'engine');
      expect(journal.lastSkinCycle?.cycle, 'skin');
      expect(journal.lastMeta?.gateState, 'red');
      expect(journal.entriesOf('meta'), hasLength(2));
    });

    test('U3.9: a missing feature directory is a misfire', () async {
      await expectLater(
        const JournalReader().read(
          feature: '999-no-such',
          projectRoot: tmp.path,
        ),
        throwsA(isA<JournalException>()),
      );
    });
  });

  group('journalFileFingerprint (U4)', () {
    test(
      'U4.1: sha256 of the bytes; null when absent; change detection',
      () async {
        final file = File(p.join(tmp.path, 'subject.dart'));
        await file.writeAsString('int w1() => 42;\n');

        final first = await journalFileFingerprint(file.path);
        expect(first, isNotNull);
        expect(first, hasLength(64));

        // Same bytes, same fingerprint.
        expect(await journalFileFingerprint(file.path), first);

        // Missing file: null; appearing is a change.
        final missing = p.join(tmp.path, 'absent.dart');
        expect(await journalFileFingerprint(missing), isNull);

        // Changed bytes: a different fingerprint.
        await file.writeAsString('int w1() => 43; // edited\n');
        expect(await journalFileFingerprint(file.path), isNot(first));

        // Null path: null.
        expect(await journalFileFingerprint(null), isNull);
      },
    );
  });
}

/// The nine schema-required entry fields (shared with the schema test's
/// expectations — mirrors the issue's field list).
class JournalEntryFields {
  static const List<String> required = [
    'feature',
    'cycle',
    'phase',
    'started_at',
    'finished_at',
    'gate_state',
    'receipts',
    'violations',
    'refs',
  ];
}

/// AST collector for the U2.5 crash-safety guard: gathers every method
/// invocation inside [JournalWriter.append] plus every `tmp` variable
/// declaration initialized from a `*.tmp'` path literal, so the test can
/// assert the write → flushToDisk → rename ordering on the journal write.
class _JournalWriteCollector extends RecursiveAstVisitor<void> {
  _JournalWriteCollector(this.invocations, this.tmpDecls);

  final List<MethodInvocation> invocations;
  final List<VariableDeclaration> tmpDecls;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    node.visitChildren(this);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    if (init != null && init.toString().contains(".tmp'")) {
      tmpDecls.add(node);
    }
    node.visitChildren(this);
  }
}

extension on JournalEntry {
  /// Test helper: a copy with overridden refs and mocks.
  JournalEntry copyWith({String? engineReceipt, Map<String, int>? mocks}) =>
      JournalEntry(
        feature: feature,
        cycle: cycle,
        phase: phase,
        startedAt: startedAt,
        finishedAt: finishedAt,
        gateState: gateState,
        receipts: receipts,
        violations: violations,
        engineReceipt: engineReceipt ?? this.engineReceipt,
        skinReceipt: skinReceipt,
        contractSchema: contractSchema,
        result: result,
        behaviors: behaviors,
        counts: counts,
        stoppedAt: stoppedAt,
        mocks: mocks ?? this.mocks,
        fingerprints: fingerprints,
        ungated: ungated,
      );
}
