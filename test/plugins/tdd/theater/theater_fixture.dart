/// TheaterFixture — builds a throwaway Dart project carrying the TDD
/// journal contracts `zfa tdd theater` renders (spec 1006, issue #1006):
///
///  - `specs/004-login-ui/tdd/artifacts.json` — a 3-behavior registry
///    (A1 green-through-the-loop, A2 red-only, A3 pending);
///  - `specs/004-login-ui/tdd/test-list.md` — the canonical 4-column
///    test list (id/behavior/traces/state);
///  - `specs/004-login-ui/tdd/cycle-log.md` — seeded through the REAL
///    `CycleLog.append` writer so the machine format (schema-1 chain
///    lines) is byte-exact by construction;
///  - `lib/` + `test/` subject/test files on disk (receipt digests are
///    computed over the real bytes);
///  - `.zfa/receipts/` generation receipts (`proof.v1` shape via the
///    real `GenerationReceipt.toJson`) — the flat store layout by
///    default, plus the per-feature `.zfa/receipts/<feature>/` layout
///    the issue names when [perFeatureReceipts] is set.
///
/// No `dart test` is ever spawned — fixtures are kernel-cache safe.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'package:zuraffa/src/core/project/receipt_store.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/models/generation_plan.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';

/// A temp project seeded for theater tests.
class TheaterFixture {
  TheaterFixture._(this.root, this.featureName);

  /// Project root (the temp directory itself).
  final Directory root;

  /// Feature directory name under `specs/`.
  final String featureName;

  /// The fixture's canonical feature: the exit criterion's
  /// `zfa tdd theater 004-login-ui`.
  static const String loginUi = '004-login-ui';

  static Future<TheaterFixture> create({
    String featureName = loginUi,
    bool perFeatureReceipts = false,
    bool withRegistry = true,
    bool withCycleLog = true,
  }) async {
    final root = Directory.systemTemp.createTempSync('zfa_theater_fixture_');
    final fx = TheaterFixture._(root, featureName);
    await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: theater_fixture
environment:
  sdk: ^3.11.0
''');
    await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
    if (withRegistry) {
      await fx._writeRegistry();
      await fx._writeTestList();
      await fx._writeSubjects();
    }
    if (withCycleLog) {
      await fx._seedCycleLog();
    }
    // Receipts land in BOTH layouts: the flat store (what ReceiptStore
    // writes today) and, when perFeatureReceipts, the per-feature
    // `.zfa/receipts/<feature>/` dir the issue names. Skipped when the
    // registry was skipped — the digests hash the subject bytes, and
    // the no-registry path asserts the load error, not the receipts.
    if (withRegistry) {
      await fx._writeReceipts(perFeature: perFeatureReceipts);
    }
    return fx;
  }

  String get featureDir => p.join(root.path, 'specs', featureName);
  String get cycleLogPath => p.join(featureDir, 'tdd', 'cycle-log.md');
  String get registryPath => p.join(featureDir, 'tdd', 'artifacts.json');

  /// Project-relative subject path for [id] (the registry's shape).
  String subjectRel(String id) => 'lib/src/login/${_snake(id)}_subject.dart';

  /// Project-relative test path for [id] (the registry's shape).
  String testRel(String id) => 'test/login/${_snake(id)}_test.dart';

  String _snake(String id) => id.toLowerCase().replaceAll('-', '_');

  // -- the journal ---------------------------------------------------

  Future<void> _writeRegistry() async {
    final records = [
      _record(
        'A1',
        'FR-001',
        'test/login/a1_test.dart::A1::the login form renders',
      ),
      _record(
        'A2',
        'FR-002',
        'test/login/a2_test.dart::A2::invalid credentials are rejected',
      ),
      _record(
        'A3',
        'FR-003',
        'test/login/a3_test.dart::A3::the session token is persisted',
      ),
    ];
    await File(registryPath).writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'feature': featureName, 'records': records}),
    );
  }

  Map<String, dynamic> _record(
    String id,
    String criterion,
    String runnableTestName,
  ) => {
    'behavior_id': id,
    'feature': featureName,
    'source_criterion': criterion,
    'test_path': testRel(id),
    'subject_path': subjectRel(id),
    'runnable_test_name': runnableTestName,
    'test_ownership': 'created',
    'subject_ownership': 'created',
    'created_at': '2026-09-05T00:00:00.000000Z',
  };

  Future<void> _writeTestList() async {
    await File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsString('''
---
feature: $featureName
loop: outside-in
---

# Test List: $featureName

## Outer loop: acceptance behaviors

| id  | behavior | traces | state |
| --- | -------- | ------ | ----- |
| A1  | the login form renders email and password fields with a submit button | FR-001 | done |
| A2  | invalid credentials are rejected with an inline error message | FR-002 | red |
| A3  | a successful login persists the session token | FR-003 | pending |
''');
  }

  Future<void> _writeSubjects() async {
    for (final id in const ['A1', 'A2', 'A3']) {
      final subject = File(p.join(root.path, subjectRel(id)));
      await subject.create(recursive: true);
      await subject.writeAsString(
        '// subject for $id (feature $featureName)\n'
        '// marker: $id-implemented\n',
      );
      final test = File(p.join(root.path, testRel(id)));
      await test.create(recursive: true);
      await test.writeAsString('// test for $id\nvoid main() {}\n');
    }
  }

  /// The journal, seeded through the REAL CycleLog.append writer: A1 has
  /// an honest red (assertion failure, with failing-assertion evidence)
  /// and a green entry carrying one generation step; A2 has only a red
  /// (load error); A3 has nothing (pending).
  Future<void> _seedCycleLog() async {
    final log = CycleLog(featureDir);

    await log.append(
      CycleLogEntry(
        behaviorId: 'A1',
        kind: CycleEntryKind.red,
        runnerCommand:
            'dart test test/login/a1_test.dart --plain-name '
            '"the login form renders"',
        exitCode: 1,
        capturedOutput:
            '00:00 +0 -1: the login form renders [E]\n'
            'Expected: exactly 2 input fields + 1 submit button\n'
            '  Actual: 0 widgets found',
        classification: FailureClass.assertionFailure,
        redEvidence: 'email and password fields render',
        sourceCriterion: 'FR-001',
        testPath: 'test/login/a1_test.dart::A1',
        timestamp: '2026-09-05T10:00:00.000000Z',
      ),
    );

    await log.append(
      CycleLogEntry(
        behaviorId: 'A1',
        kind: CycleEntryKind.green,
        runnerCommand:
            'dart test test/login/a1_test.dart --plain-name '
            '"the login form renders"',
        exitCode: 0,
        capturedOutput: '00:00 +1: the login form renders',
        sourceCriterion: 'FR-001',
        testPath: 'test/login/a1_test.dart::A1',
        timestamp: '2026-09-05T10:05:00.000000Z',
        generationSteps: [
          GenerationStep(
            command: 'zfa tdd gen A1 --feature $featureName',
            exitCode: 0,
            output: 'gen: behavior=A1 outcome=generated',
            purpose: 'render the login form subject',
          ),
        ],
        suiteBaselineFailures: 1,
        suiteGuardFailures: 0,
      ),
    );

    await log.append(
      CycleLogEntry(
        behaviorId: 'A2',
        kind: CycleEntryKind.red,
        runnerCommand:
            'dart test test/login/a2_test.dart --plain-name '
            '"invalid credentials are rejected"',
        exitCode: 1,
        capturedOutput:
            '00:00 +0 -1: loading test/login/a2_test.dart [E]\n'
            'Failed to load "test/login/a2_test.dart": '
            'Error: library not found',
        classification: FailureClass.loadError,
        sourceCriterion: 'FR-002',
        testPath: 'test/login/a2_test.dart::A2',
        timestamp: '2026-09-05T11:00:00.000000Z',
      ),
    );
  }

  // -- the receipts ---------------------------------------------------

  /// Write the #807 generation receipts covering A1's and A2's subjects.
  /// Flat store by default; [perFeature] writes the same documents under
  /// `.zfa/receipts/<feature>/` (the issue's layout) instead.
  Future<void> _writeReceipts({required bool perFeature}) async {
    final receipts = <GenerationReceipt>[
      _receipt(
        target: 'A1',
        covered: [subjectRel('A1'), testRel('A1')],
        at: DateTime.parse('2026-09-05T10:02:00.000000Z'),
      ),
      _receipt(
        target: 'A2',
        covered: [subjectRel('A2')],
        at: DateTime.parse('2026-09-05T11:30:00.000000Z'),
      ),
    ];
    const encoder = JsonEncoder.withIndent('  ');
    final dir = perFeature
        ? Directory(p.join(root.path, '.zfa', 'receipts', featureName))
        : Directory(p.join(root.path, '.zfa', 'receipts'));
    await dir.create(recursive: true);
    for (final receipt in receipts) {
      await File(
        p.join(dir.path, _portableName(receipt)),
      ).writeAsString(encoder.convert(receipt.toJson()));
    }
  }

  /// The ReceiptStore.save portable-file-name shape (colons stripped).
  String _portableName(GenerationReceipt receipt) {
    final stamp = receipt.at.toUtc().toIso8601String().replaceAll(':', '-');
    final cmd = receipt.command.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return '$stamp-$cmd-${receipt.target}.json';
  }

  GenerationReceipt _receipt({
    required String target,
    required List<String> covered,
    required DateTime at,
  }) {
    final files = <GenerationReceiptFile>[];
    for (final rel in covered) {
      final bytes = File(p.join(root.path, rel)).readAsBytesSync();
      files.add(
        GenerationReceiptFile(
          path: rel,
          action: 'create',
          sha256: crypto.sha256.convert(bytes).toString(),
          bytes: bytes.length,
        ),
      );
    }
    return GenerationReceipt(
      command: 'zfa tdd gen',
      target: target,
      repro: 'zfa tdd gen $target --feature $featureName',
      at: at,
      generatorVersion: '6.1.0',
      input: {'feature': featureName, 'behavior': target},
      files: files,
    );
  }
}
