// Issue #1625 — the blocked-contract stop names the TEST file as the hand
// surface and suggests `zfa tdd wire … --entity <X>` — which fails when no
// such entity exists.
//
// The #1589 hint fixed the dead end (the stop now names a hand surface), but
// it names the wrong file: `seamPathFor` builds candidates ONLY under
// `test/tdd/…`, so the stop points at the generated, registry-owned contract
// TEST instead of the implementation seam it imports — the subject
// (`lib/tdd/<feature>/<id>_subject.dart`, the throwing stub). And `hintLine`
// synthesizes `zfa tdd wire <id> --entity <E>` from the dotted contract trace
// without checking that the entity exists, printing a command that `zfa tdd
// wire` itself refuses the moment no `lib/src/domain/entities/<snake>/` is
// on disk (the repro's `Calculator` shape).
//
// The fix under test (hand-surface detection + hint logic ONLY — the #1007
// block gate, the #1544 park semantics and the wire mechanics are untouched):
//
//   1. `seamPathFor` prefers the subject seam
//      (`lib/tdd/<feature>/<id>_subject.dart`) existence-first, falling back
//      to the #827 test candidates; the canonical display fallback (nothing
//      on disk) is the subject path.
//   2. `hintLine` prints the with-entity wire example ONLY when that entity
//      actually exists; when it does not, the hint carries the hand-implement
//      instruction + the `zfa entity create` prerequisite instead.
//   3. A fresh spec's first blocked behavior (subject on disk, no entity)
//      points at the subject file — the path that makes the run converge.
//
// Fast tier throughout: the fake zfa scripts every step, no `dart test`
// spawn (kernel-cache-safe fixture rule).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_blocked_receipt.dart';
import 'package:zuraffa/src/plugins/tdd/services/hand_surface.dart';

import '../helpers/tdd_fixture.dart';

/// Reads the process-global `dart:io exitCode` and immediately resets it
/// (the same suite-wide flake guard bug_1589_contract_blocked_resume_test.dart
/// uses).
int takeExitCode() {
  final code = exitCode;
  exitCode = 0;
  return code;
}

const feature = '004-calculator';

void main() {
  group('seamPathFor: the subject seam wins over the test file (issue #1625)',
      () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tdd_1625_seam_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('an existing subject is named over an existing test', () {
      final subject = File(
        p.join(root.path, 'lib', 'tdd', feature, 'contract_a1_subject.dart'),
      )..createSync(recursive: true);
      File(
        p.join(root.path, 'test', 'tdd', feature, 'contract_a1_test.dart'),
      ).createSync(recursive: true);

      final seam = HandSurface.seamPathFor(
        projectRoot: root.path,
        feature: feature,
        behaviorId: 'contract:A1',
      );

      expect(seam, 'lib/tdd/$feature/contract_a1_subject.dart');
      expect(
        p.join(root.path, seam),
        subject.path,
        reason: 'the named file is the one on disk',
      );
    });

    test('a test-only project still names the existing test (fallback)', () {
      File(
        p.join(root.path, 'test', 'tdd', feature, 'contract_a1_test.dart'),
      ).createSync(recursive: true);

      final seam = HandSurface.seamPathFor(
        projectRoot: root.path,
        feature: feature,
        behaviorId: 'contract:A1',
      );

      expect(seam, 'test/tdd/$feature/contract_a1_test.dart');
    });

    test('nothing on disk: the canonical display fallback is the SUBJECT '
        'path — the file the operator creates implements in', () {
      final seam = HandSurface.seamPathFor(
        projectRoot: root.path,
        feature: feature,
        behaviorId: 'contract:A1',
      );

      expect(seam, 'lib/tdd/$feature/contract_a1_subject.dart');
    });
  });

  group('hintLine: the wire hint is gated on entity existence (issue #1625)',
      () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('tdd_1625_hint_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test('entity exists: the with-entity wire example is printed', () {
      File(
        p.join(
          root.path,
          'lib',
          'src',
          'domain',
          'entities',
          'user',
          'user.dart',
        ),
      ).createSync(recursive: true);

      final hint = HandSurface.hintLine(
        behaviorId: 'contract:A1',
        seamPath: 'lib/tdd/$feature/contract_a1_subject.dart',
        contract: 'User.validateEmail',
        projectRoot: root.path,
      );

      expect(hint, contains('zfa tdd wire contract:A1 --entity User'));
    });

    test('entity MISSING: the hand-implement instruction is printed instead '
        '— never a wire command that would fail', () {
      final hint = HandSurface.hintLine(
        behaviorId: 'contract:A1',
        seamPath: 'lib/tdd/$feature/contract_a1_subject.dart',
        contract: 'User.validateEmail',
        projectRoot: root.path,
      );

      expect(
        hint,
        contains('lib/tdd/$feature/contract_a1_subject.dart'),
        reason: hint,
      );
      expect(hint, contains('zfa entity create -n User'), reason: hint);
      expect(
        hint,
        isNot(contains('e.g. `zfa tdd wire contract:A1 --entity User`')),
        reason: hint,
      );
    });

    test('undotted contract: no entity to check, the bare wire example '
        'stands (unchanged #1589 degradation)', () {
      final hint = HandSurface.hintLine(
        behaviorId: 'contract:A1',
        seamPath: 'lib/tdd/$feature/contract_a1_subject.dart',
        projectRoot: root.path,
      );

      expect(hint, contains('zfa tdd wire contract:A1'));
    });
  });

  group('run: the blocked stop names the subject seam (issue #1625)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: feature, writeProfile: false);
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'contract:A1',
          description:
              'Calculator.add(int a, int b) -> int (entity method contract)',
          traces: 'Calculator.add',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
      await fx.setStepOutcome('verify-red', 'contract:A1', 'blocked');
      // The fresh-run shape: the generated contract test AND its subject
      // stub are both on disk (the test imports the subject and throws on
      // it) — but no `Calculator` entity was ever created.
      seedSeamTest(fx, 'contract:A1');
      seedSubject(fx, 'contract:A1');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('the park note names the SUBJECT, not the generated test', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(
        out,
        contains('seam lib/tdd/$feature/contract_a1_subject.dart'),
        reason: out,
      );
      // The test file is a generated artifact — it is not the hand surface.
      expect(
        out,
        isNot(contains('seam test/tdd/$feature/contract_a1_test.dart')),
        reason: out,
      );
    });

    test('with no entity on disk the hint carries the hand-implement '
        'instruction, not a failing wire command', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(
        out,
        contains('zfa entity create -n Calculator'),
        reason: out,
      );
      expect(
        out,
        isNot(contains('e.g. `zfa tdd wire contract:A1 --entity Calculator`')),
        reason: out,
      );
      // The BLOCKED verdict, the contract lane and the state machine are
      // UNTOUCHED (the #1007/#1544 pins still hold).
      expect(out, contains('contract:A1 verify-red -> blocked'));
      expect(out, contains('result=blocked'));
      expect(takeExitCode(), 1, reason: out);
    });

    test('with the entity on disk the with-entity wire example is printed',
        () async {
      seedEntity(fx, 'Calculator');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();

      expect(
        out,
        contains('zfa tdd wire contract:A1 --entity Calculator'),
        reason: out,
      );
    });

    test('the terminal result=blocked block names the subject seam too',
        () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();

      expect(
        out,
        contains('seam lib/tdd/$feature/contract_a1_subject.dart'),
        reason: out,
      );
    });
  });

  group('verify-red + make: the blocked refusal names the subject seam '
      '(issue #1625)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: feature);
      final seamPath = seedSeamTest(fx, 'contract:A1');
      seedSubject(fx, 'contract:A1');
      await fx.registerBehavior(
        id: 'contract:A1',
        description:
            'Calculator.add(int a, int b) -> int (entity method contract)',
        sourceCriterion: 'Calculator.add',
        testPath: seamPath,
        writeTestFile: false,
      );
      await fx.seedTestList([
        (
          id: 'contract:A1',
          description:
              'Calculator.add(int a, int b) -> int (entity method contract)',
          traces: 'Calculator.add',
          state: 'BLOCKED',
          kind: 'contract',
        ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    /// Backdate every watched input (the #1544 watch set) behind [verdictAt]
    /// so the unchanged-world predicate agrees (mirrors the #1589 make arm).
    void backdateWorld(DateTime verdictAt) {
      final before = verdictAt.subtract(const Duration(hours: 1));
      File(
        p.join(fx.featureDir, 'tdd', 'test-list.md'),
      ).setLastModified(before);
      for (final dir in [
        Directory(p.join(fx.root.path, 'lib')),
        Directory(p.join(fx.root.path, 'test')),
      ]) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File) entity.setLastModified(before);
        }
      }
    }

    test('make on a parked contract names the SUBJECT seam + the '
        'entity-create prerequisite (no entity on disk)', () async {
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      backdateWorld(verdictAt);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'contract:A1',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);

      expect(out, contains('implement seam first'), reason: out);
      expect(
        out,
        contains('seam lib/tdd/$feature/contract_a1_subject.dart'),
        reason: out,
      );
      expect(
        out,
        isNot(contains('seam test/tdd/$feature/contract_a1_test.dart')),
        reason: out,
      );
      expect(
        out,
        isNot(contains('e.g. `zfa tdd wire contract:A1 --entity Calculator`')),
        reason: out,
      );
      expect(takeExitCode(), isNot(0), reason: out);
    });
  });
}

/// Seed the generated contract test (the seam file the verdict runs), the
/// #827 namespaced layout. Returns the file's absolute path.
String seedSeamTest(TddFixture fx, String behaviorId) {
  final snakeId = behaviorId.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final file = File(
    p.join(fx.root.path, 'test', 'tdd', fx.featureName, '${snakeId}_test.dart'),
  );
  file.createSync(recursive: true);
  file.writeAsStringSync('// kind: contract\nvoid main() {}\n');
  return file.path;
}

/// Seed the generated subject stub — the implementation seam the contract
/// test imports (the `lib/tdd/<feature>/<id>_subject.dart` convention,
/// issue #1625).
void seedSubject(TddFixture fx, String behaviorId) {
  final snakeId = behaviorId.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final file = File(
    p.join(
      fx.root.path,
      'lib',
      'tdd',
      fx.featureName,
      '${snakeId}_subject.dart',
    ),
  );
  file.createSync(recursive: true);
  file.writeAsStringSync(
    "int add(int a, int b) =>\n"
    "    throw UnimplementedError('not implemented');\n",
  );
}

/// Seed a generated entity file exactly where `zfa entity create` writes it
/// (`lib/src/domain/entities/<snake>/<snake>.dart`).
void seedEntity(TddFixture fx, String entityName) {
  final snake = entityName.toLowerCase();
  final file = File(
    p.join(
      fx.root.path,
      'lib',
      'src',
      'domain',
      'entities',
      snake,
      '$snake.dart',
    ),
  );
  file.createSync(recursive: true);
  file.writeAsStringSync('class $entityName {}\n');
}

/// Seed the blocked verdict's receipt exactly the way the real
/// `zfa tdd verify-red` writes it (`contract-blocked.<id>.json` under
/// `<project>/.zfa/receipts/`, schema `contract-blocked.v1`).
Future<void> seedBlockedReceipt(
  TddFixture fx,
  String behaviorId,
  DateTime blockedAt,
) async {
  final store = ContractBlockedReceiptStore(projectRoot: fx.root.path);
  await store.write(
    ContractBlockedReceipt(
      behavior: behaviorId,
      feature: fx.featureName,
      contract: 'Calculator.add',
      command: 'dart test test/tdd/$feature/contract_a1_test.dart',
      exitCode: 1,
      outputExcerpt:
          '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
          'Calculator.add blocked contract [E]\n'
          '00:00 +0 -1: Some tests failed.',
      blockedAt: blockedAt.toIso8601String(),
    ),
  );
}
