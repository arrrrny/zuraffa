// SPEC 1136 lane 5 — the proof receipt chain closes over simulation
// worlds and spec fuzz (EPIC 5):
//
//   F1 — `zfa spec fuzz` writes a proof.v1 receipt
//        (.zfa/receipts/spec-fuzz-<feature>.json) pinning the committed
//        spec-fuzz report bytes + the spec digest, with the round's
//        verdict extras.
//   F2 — tampering the spec-fuzz report after the run is drift (the
//        receipt's digest walk flags it).
//   W1 — a world-run receipt whose manifest hash matches verifies
//        green (no world_drift finding).
//   W2 — mutating the world manifest after the run → world_drift
//        finding naming both hashes (drift detected as receipt
//        mismatch).
//   W3 — a world-run receipt whose manifest is gone → world_drift.
//   K1 — the proof report carries a kind breakdown (world, spec-fuzz,
//        ...) — the epic's "validates every receipt" surface.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/proof/proof_checker.dart';

import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_fuzz_auditor.dart';
import 'package:zuraffa/src/simulation/worlds/world_manifest.dart';
import 'package:zuraffa/src/simulation/worlds/world_run_receipt.dart';

/// The toy greeter fixture (the auditor test's shape): a weak spec whose
/// mutants survive, with injectable spawns (no real dart processes).
Future<Directory> _greeterProject() async {
  final root = await Directory.systemTemp.createTemp('proof_1136_fuzz_');
  const feature = 'fixture-greeter';
  final featureDir = p.join(root.path, 'specs', feature);
  await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Fixture Greeter (weak)

**Feature Branch**: `fixture-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A vague greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return a greeting message.
  traces: Greeter
''');
  await File(p.join(root.path, 'test', 'tdd', feature, 'a1_test.dart'))
      .create(recursive: true)
      .then(
        (f) => f.writeAsString('''
// GENERATED TEST — spec 044.
library;
import 'package:test/test.dart';
import '../../../lib/tdd/$feature/a1_subject.dart' as subject;
void main() {
  test('A1', () {
    final result = (() {
      try { subject.subjectUnderTest(); return null; }
      on UnimplementedError catch (e) { return e; }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
'''),
      );
  await File(p.join(root.path, 'lib', 'tdd', feature, 'a1_subject.dart'))
      .create(recursive: true)
      .then(
        (f) => f.writeAsString('''
// IMPLEMENTED SUBJECT.
library;
int subjectUnderTest() => 42;
'''),
      );
  await File(p.join(featureDir, 'tdd', 'artifacts.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'feature': feature,
      'records': [
        {
          'behavior_id': 'A1',
          'feature': feature,
          'source_criterion': 'AC-1',
          'test_path': 'test/tdd/$feature/a1_test.dart',
          'subject_path': 'lib/tdd/$feature/a1_subject.dart',
          'runnable_test_name': 'A1 — demo',
          'test_ownership': 'created',
          'subject_ownership': 'created',
          'created_at': '2026-09-18T00:00:00Z',
        },
      ],
    }),
  );
  return root;
}

/// The honest fake spawn (the auditor test's): reads the test file the
/// writer regenerated, extracts the `equals(<n>)` pin, and compares it
/// against the paired subject's return value — green when they match, red
/// otherwise. A test without an `equals(<n>)` pin is green (the writer's
/// generic shape passes against implemented subjects).
Future<ProcessResult> _fakeSpawn(
  String executable,
  List<String> args,
  String workingDirectory,
  Duration timeout,
) async {
  final testPath = args.where((a) => a.endsWith('_test.dart')).first;
  final abs = p.isAbsolute(testPath)
      ? testPath
      : p.join(workingDirectory, testPath);
  final content = File(abs).readAsStringSync();
  final equals = RegExp(r'equals\((\d+)\)').firstMatch(content);
  final subjectMatch = RegExp(
    r"import\s+'([^']*_subject\.dart)'\s+as\s+subject",
  ).firstMatch(content);
  if (equals == null || subjectMatch == null) {
    return ProcessResult(42, 0, 'All tests passed!', '');
  }
  final subjectPath = p.normalize(
    p.join(p.dirname(abs), subjectMatch.group(1)!),
  );
  final subjectContent = File(subjectPath).readAsStringSync();
  final value = RegExp(r'=>\s*(\d+);').firstMatch(subjectContent);
  final expected = int.parse(equals.group(1)!);
  final actual = value == null ? null : int.parse(value.group(1)!);
  if (actual == expected) {
    return ProcessResult(42, 0, 'All tests passed!', '');
  }
  return ProcessResult(
    42,
    1,
    '00:00 +0: $testPath [E]\n'
        'Expected: <$expected>\n'
        '  Actual: <$actual>',
    '',
  );
}

/// A minimal certified world manifest document for the 1136 fixture
/// feature, written to `specs/<feature>/tdd/worlds/<scenario>.world.json`.
Future<WorldManifest> _writeWorld(
  Directory root,
  String feature, {
  required String scenario,
  String? descriptionOverride,
}) async {
  final manifest = WorldManifest(
    schema: WorldManifest.schemaVersion,
    spec: 1136,
    scenario: scenario,
    feature: feature,
    version: 1,
    seed: 1136,
    touchpoints: [
      WorldTouchpoint(
        name: 'PaymentGateway',
        type: 'service',
        family: 'generic',
        priority: 'P1',
        contract: 'charge(payment) -> ChargeResult',
        methods: const [
          ContractMethod(
            name: 'charge',
            params: ['payment'],
            returns: 'ChargeResult',
          ),
        ],
      ),
    ],
    latency: const {'PaymentGateway': WorldLatencyBands.certified},
    storms: const [],
    corpus: const {
      'PaymentGateway': {
        'charge': {
          'fixture': {'chargeId': 'ch_1'},
        },
      },
    },
    behaviors: const [
      WorldBehavior(
        id: 'charge-once',
        driver: 'invoke',
        touchpoint: 'PaymentGateway',
        method: 'charge',
        args: {},
        maxAttempts: 1,
        expect: 'green',
      ),
    ],
    description: descriptionOverride ?? 'the 1136 proof-check fixture',
  );
  final dir = Directory(p.join(root.path, 'specs', feature, 'tdd', 'worlds'))
    ..createSync(recursive: true);
  await File(
    p.join(dir.path, '$scenario.world.json'),
  ).writeAsString(manifest.toFileContents());
  return manifest;
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('proof_1136_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  group('F1/F2: spec-fuzz receipts (proof.v1)', () {
    test(
      'F1: the auditor writes a proof.v1 receipt pinning the reports',
      () async {
        final fuzzRoot = await _greeterProject();
        addTearDown(() => fuzzRoot.delete(recursive: true));
        final featureDir = p.join(fuzzRoot.path, 'specs', 'fixture-greeter');

        final auditor = SpecFuzzAuditor(
          featureDir: featureDir,
          workingDirectory: fuzzRoot.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: _fakeSpawn,
        );
        final report = await auditor.run();
        expect(report.mutationWasRun, isTrue, reason: 'the round ran');

        final receiptFile = File(
          p.join(
            fuzzRoot.path,
            '.zfa',
            'receipts',
            'spec-fuzz-fixture-greeter.json',
          ),
        );
        expect(receiptFile.existsSync(), isTrue, reason: 'the fuzz receipt');
        final doc =
            jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
        expect(doc['schema'], 'proof.v1');
        expect(doc['command'], 'spec fuzz');
        expect(doc['survived'], report.survivedCount);
        expect(doc['killed'], report.killedCount);
        expect(doc['mutations'], report.outcomes.length);
        expect(doc['gate'], report.gate.name);
        expect(doc['fuzz_was_run'], isTrue);

        // The receipt pins the committed report bytes.
        final files = (doc['files'] as List)
            .map((f) => (f as Map)['path'] as String)
            .toSet();
        expect(files, contains('specs/fixture-greeter/tdd/spec-fuzz.json'));
        expect(files, contains('specs/fixture-greeter/tdd/spec-fuzz.md'));
        // And the spec the fuzz graded.
        expect(doc['spec'], isA<Map>());
        expect((doc['spec'] as Map)['path'], 'specs/fixture-greeter/spec.md');

        // The proof checker verifies the whole thing green.
        final checker = ProofChecker(projectRoot: fuzzRoot.path);
        final proof = await checker.check();
        expect(proof.ok, isTrue, reason: proof.findings.toString());
      },
    );

    test('F2: tampering the spec-fuzz report after the run is drift', () async {
      final fuzzRoot = await _greeterProject();
      addTearDown(() => fuzzRoot.delete(recursive: true));
      final featureDir = p.join(fuzzRoot.path, 'specs', 'fixture-greeter');

      final auditor = SpecFuzzAuditor(
        featureDir: featureDir,
        workingDirectory: fuzzRoot.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      await auditor.run();

      // Hand-edit the committed report after the receipt pinned it.
      final reportFile = File(p.join(featureDir, 'tdd', 'spec-fuzz.md'));
      reportFile.writeAsStringSync(
        '${reportFile.readAsStringSync()}\n<!-- hand edit -->\n',
      );

      final checker = ProofChecker(projectRoot: fuzzRoot.path);
      final proof = await checker.check();
      expect(proof.ok, isFalse);
      expect(
        proof.findings.map((f) => f.kind),
        contains(ProofFinding.kindModified),
      );
      expect(
        proof.findings
            .where((f) => f.kind == ProofFinding.kindModified)
            .map((f) => f.path),
        contains('specs/fixture-greeter/tdd/spec-fuzz.md'),
      );
    });
  });

  group('W1/W2/W3: world-hash validation', () {
    test('W1: a matching world manifest verifies (no world_drift)', () async {
      const feature = 'w1-feature';
      final manifest = await _writeWorld(root, feature, scenario: 'v3');

      final store = WorldRunReceiptStore(projectRoot: root.path);
      await store.save(
        WorldRunReceipt(
          scenario: 'v3',
          feature: feature,
          worldHash: manifest.worldHash,
          seed: 1136,
          verdict: 'GREEN',
          passed: true,
          worldValid: true,
          plays: 1,
          runDigest: 'a' * 64,
          virtualElapsedMs: 5,
          at: DateTime.now().toUtc().toIso8601String(),
          path: '',
        ),
      );

      final checker = ProofChecker(projectRoot: root.path);
      final report = await checker.check();
      expect(report.ok, isTrue, reason: report.findings.toString());
      expect(
        report.findings.where((f) => f.kind == ProofFinding.kindWorldDrift),
        isEmpty,
      );
    });

    test(
      'W2: mutating the world manifest after the run is world_drift',
      () async {
        const feature = 'w2-feature';
        final manifest = await _writeWorld(root, feature, scenario: 'v3');
        final originalHash = manifest.worldHash;

        final store = WorldRunReceiptStore(projectRoot: root.path);
        await store.save(
          WorldRunReceipt(
            scenario: 'v3',
            feature: feature,
            worldHash: originalHash,
            seed: 1136,
            verdict: 'GREEN',
            passed: true,
            worldValid: true,
            plays: 1,
            runDigest: 'a' * 64,
            virtualElapsedMs: 5,
            at: DateTime.now().toUtc().toIso8601String(),
            path: '',
          ),
        );

        // Mutate the world's reality after the green receipt named it.
        await _writeWorld(
          root,
          feature,
          scenario: 'v3',
          descriptionOverride:
              'the 1136 proof-check fixture (MUTATED — new failure '
              'schedule semantics)',
        );

        final checker = ProofChecker(projectRoot: root.path);
        final report = await checker.check();
        expect(report.ok, isFalse);
        final drift = report.findings
            .where((f) => f.kind == ProofFinding.kindWorldDrift)
            .toList();
        expect(drift, hasLength(1));
        expect(
          drift.single.detail,
          contains(originalHash.substring(0, 12)),
          reason: 'the finding names the receipted hash',
        );
        expect(drift.single.receipt, 'world-run-v3.json');
      },
    );

    test(
      'W3: a world-run receipt whose manifest is gone is world_drift',
      () async {
        const feature = 'w3-feature';
        final manifest = await _writeWorld(root, feature, scenario: 'v3');

        final store = WorldRunReceiptStore(projectRoot: root.path);
        await store.save(
          WorldRunReceipt(
            scenario: 'v3',
            feature: feature,
            worldHash: manifest.worldHash,
            seed: 1136,
            verdict: 'GREEN',
            passed: true,
            worldValid: true,
            plays: 1,
            runDigest: 'a' * 64,
            virtualElapsedMs: 5,
            at: DateTime.now().toUtc().toIso8601String(),
            path: '',
          ),
        );

        // The manifest disappears (moved / deleted): the green is no
        // longer attributable to any committed world.
        File(
          p.join(root.path, 'specs', feature, 'tdd', 'worlds', 'v3.world.json'),
        ).deleteSync();

        final checker = ProofChecker(projectRoot: root.path);
        final report = await checker.check();
        expect(report.ok, isFalse);
        expect(
          report.findings.map((f) => f.kind),
          contains(ProofFinding.kindWorldDrift),
        );
      },
    );
  });

  test('K1: the proof report carries a receipt-kind breakdown', () async {
    const feature = 'k1-feature';
    final manifest = await _writeWorld(root, feature, scenario: 'v3');
    final store = WorldRunReceiptStore(projectRoot: root.path);
    await store.save(
      WorldRunReceipt(
        scenario: 'v3',
        feature: feature,
        worldHash: manifest.worldHash,
        seed: 1136,
        verdict: 'GREEN',
        passed: true,
        worldValid: true,
        plays: 1,
        runDigest: 'a' * 64,
        virtualElapsedMs: 5,
        at: DateTime.now().toUtc().toIso8601String(),
        path: '',
      ),
    );

    final report = await ProofChecker(projectRoot: root.path).check();
    final kinds = report.receiptKinds;
    expect(kinds, isNotNull);
    expect(kinds!['world'], 1);
    // The JSON verdict exposes it too.
    expect((report.toJson()['kinds'] as Map)['world'], 1);
  });
}
