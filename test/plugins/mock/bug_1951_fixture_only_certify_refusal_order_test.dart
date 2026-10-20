// Issue #1951: `zfa mock create <Enum>` (with or without `--certify`) was
// unsatisfiable again — the #1894 absent-interface refusal inside
// [MockCertificationService.certify] fired BEFORE the fixture-only
// classification was computed, so the #1887/#1037/#1747 enum short-circuit
// was unreachable on the generation path. The generator deliberately never
// emits a CRUD datasource surface for an enum, the service derived the
// interface path anyway, and every enum `mock create` exited 1 after the
// fixture was already written (the escalation: the headless route failed
// too, because `certify()` runs unconditionally for every non-dry-run
// generation).
//
// Contract pinned here (remediation):
// - `certify()` classifies fixture-only BEFORE the absence refusals and
//   skips both (interface + mock) for a fixture-only entity, returning a
//   certification with `fixtureOnly: true` and an empty surface;
// - the #1894 refusal is INTACT for a real CRUD entity whose declared
//   interface is absent — this fix reorders, it does not weaken;
// - `zfa mock create <Enum>` exits 0 (plain and `--certify`), the fixture
//   on disk being the whole deliverable;
// - `zfa mock verify <Enum>` reports the same fixture-only green instead
//   of the missing-file refusal, while a real entity's missing artifacts
//   still refuse;
// - PR #1954 review follow-ups: fixture-only certification REFUSES when
//   no fixture exists on disk (a vacuous green — `mock verify` refuses
//   the same state), and verify runs the fixture through the REAL gate
//   (`MockCertifier.gate`), so a compile-error fixture fails instead of
//   passing unanalyzed; the `--json` pass envelope pins
//   `details['fixtureOnly']`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/core/verdict_envelope.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/mock/services/mock_certification.dart';

import 'mock_cli_guard.dart';

// The issue's exact entity: a real enum declared in its own per-entity
// folder (the v7 fixed layout), no `enums/` barrel — and NO
// `data/datasources/subscription_tier/` directory, because #1037 skips the
// CRUD surface for enums by design.
const _enumSource = 'enum SubscriptionTier { free, pro, max }\n';

const _fixtureSource = '''
class SubscriptionTierMockData {
  static const values = <SubscriptionTier>[
    SubscriptionTier.free,
    SubscriptionTier.pro,
    SubscriptionTier.max,
  ];
}
''';

// A real CRUD entity (identity + copyWithField + Patch): the shape the
// #1894 refusal must KEEP guarding.
const _productSource = '''
class Product {
  final String id;
  final String name;
  const Product({required this.id, required this.name});

  Product copyWithField(Object field, Object? value) => this;
}

class ProductPatch {}
''';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1951_');
    scaffoldEnumProject(tempDir.path);
  });

  tearDown(() async {
    // Restore the production analyze runner (static test seam).
    MockCertifier.analyzeRunnerOverride = null;
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The entity tree of the fixture project (absolute: certify resolves
  /// the fixture-only probe through its projectRoot, so tests stay honest
  /// regardless of the process cwd).
  String entityTreeOf(String root) => p.join(root, 'lib', 'src');

  Future<String> runCli(List<String> args) => CwdGuard.exclusive(
    () => CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['-C', tempDir.path, ...args]),
  );

  /// Deterministic green analyze stub for the fast tier (the --certify
  /// gate's scoped `dart analyze` over the fixture files).
  void greenAnalyze() {
    MockCertifier.analyzeRunnerOverride = (files, cwd) async =>
        (exitCode: 0, output: 'Analyzing ... No issues found!');
  }

  group('#1951 — certify classifies fixture-only BEFORE the refusals', () {
    test('certify() returns a fixture-only certification for an enum '
        'instead of refusing the by-design-absent interface', () async {
      final certification = await MockCertificationService.certify(
        entity: 'SubscriptionTier',
        outputDir: entityTreeOf(tempDir.path),
        files: [
          GeneratedFile(
            path: p.join(
              tempDir.path,
              'lib',
              'src',
              'data',
              'mock',
              'subscription_tier_mock_data.dart',
            ),
            type: 'mock_data',
            action: 'created',
          ),
        ],
        projectRoot: tempDir.path,
      );

      expect(
        certification.fixtureOnly,
        isTrue,
        reason: 'the enum is fixture-only — the whole #1951 point',
      );
      expect(certification.interfaceMethods, isEmpty);
      expect(certification.missingMethods, isEmpty);
      expect(certification.conformance, isTrue);
      expect(certification.fixtures, hasLength(1));
    });

    test('the #1894 refusal stays intact for a real CRUD entity whose '
        'declared interface is absent', () async {
      final productDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities', 'product'),
      )..createSync(recursive: true);
      File(
        p.join(productDir.path, 'product.dart'),
      ).writeAsStringSync(_productSource);

      await expectLater(
        MockCertificationService.certify(
          entity: 'Product',
          outputDir: entityTreeOf(tempDir.path),
          files: const [],
          projectRoot: tempDir.path,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('does not exist'),
          ),
        ),
        reason: 'reordering the fixture-only check must not weaken #1894',
      );
    });

    test('certify() refuses a fixture-only entity when no fixture exists '
        'on disk (the vacuous-green refusal)', () async {
      // PR #1954 review: the fixture collection skips an absent file and
      // the gate would run with nothing to analyze — while `mock verify`
      // refuses that same state. Certification must refuse it too.
      final fixturePath = p.join(
        tempDir.path,
        'lib',
        'src',
        'data',
        'mock',
        'subscription_tier_mock_data.dart',
      );
      File(fixturePath).deleteSync();

      await expectLater(
        MockCertificationService.certify(
          entity: 'SubscriptionTier',
          outputDir: entityTreeOf(tempDir.path),
          files: [
            GeneratedFile(
              path: fixturePath,
              type: 'mock_data',
              action: 'created',
            ),
          ],
          projectRoot: tempDir.path,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('mock-data fixture exists on disk'),
          ),
        ),
        reason:
            'a fixture-only certification with nothing to analyze must '
            'not pass — generate the fixture first',
      );
    });
  });

  group('#1951 — zfa mock create <Enum> (the reported repro)', () {
    test('plain `mock create SubscriptionTier` exits 0 and writes the '
        'fixture (the escalation: the headless route)', () async {
      final out = await runCli(['mock', 'create', 'SubscriptionTier']);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'the fixture IS the deliverable for an enum — '
            'pre-fix the generation-path refusal exited 1, output:\n$out',
      );
      expect(
        File(
          p.join(
            tempDir.path,
            'lib',
            'src',
            'data',
            'mock',
            'subscription_tier_mock_data.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        out,
        isNot(contains('cannot certify')),
        reason: 'the unsatisfiable refusal must be gone',
      );
    });

    test('`mock create SubscriptionTier --certify` exits 0 — the enum '
        'certifies as fixture-only', () async {
      greenAnalyze();
      final out = await runCli([
        'mock',
        'create',
        'SubscriptionTier',
        '--certify',
      ]);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'an enum certifies as fixture-only (mock data written, no '
            'datasource surface to prove) — output:\n$out',
      );
      expect(out, isNot(contains('cannot certify')));
    });
  });

  group('#1951 — zfa mock verify <Enum>', () {
    /// Deterministic red analyze stub: the gate reports a compile error in
    /// the fixture (the PR #1954 review shape — a broken fixture is drift,
    /// not a pass).
    void redAnalyze() {
      MockCertifier.analyzeRunnerOverride = (files, cwd) async => (
        exitCode: 1,
        output:
            "Analyzing...\nerror - Undefined name 'SubscriptionTier' · "
            'subscription_tier_mock_data.dart:2:30 · undefined_identifier\n',
      );
    }

    test('reports the fixture-only green instead of the missing-file '
        'refusal', () async {
      await runCli(['mock', 'create', 'SubscriptionTier']);
      greenAnalyze();
      final out = await runCli(['mock', 'verify', 'SubscriptionTier']);

      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.success,
        reason:
            'a fixture-only entity has no datasource surface to verify — '
            'the green IS the report, output:\n$out',
      );
      expect(out, contains('fixture-only'));
      expect(out, isNot(contains('missing_file')));
    });

    test('--json emits a canonical pass envelope with fixtureOnly', () async {
      await runCli(['mock', 'create', 'SubscriptionTier']);
      greenAnalyze();
      final out = await runCli([
        'mock',
        'verify',
        'SubscriptionTier',
        '--json',
      ]);

      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.success);
      final envelope = VerdictEnvelope.tryParse(out);
      expect(
        envelope,
        isNotNull,
        reason: 'the last stdout line must be the canonical envelope:\n$out',
      );
      expect(envelope!.verdict, VerdictKind.pass);
      expect(envelope.subject!.id, 'SubscriptionTier');
      expect(envelope.findings, isEmpty);
      expect(envelope.details['fixtureOnly'], isTrue);
    });

    test('a compile-error fixture FAILS the gate (PR #1954 review: the '
        'fixture is verified, not accepted unconditionally)', () async {
      await runCli(['mock', 'create', 'SubscriptionTier']);
      redAnalyze();
      final out = await runCli(['mock', 'verify', 'SubscriptionTier']);

      expect(
        CliRunner.lastDispatchedExitCode,
        ExitProtocol.failure,
        reason:
            'a broken fixture is drift even with no datasource '
            'surface — output:\n$out',
      );
      expect(out, contains('analyze_error'));
    });

    test('--json reports the broken fixture as a fail envelope that keeps '
        'fixtureOnly', () async {
      await runCli(['mock', 'create', 'SubscriptionTier']);
      redAnalyze();
      final out = await runCli([
        'mock',
        'verify',
        'SubscriptionTier',
        '--json',
      ]);

      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.failure);
      final envelope = VerdictEnvelope.tryParse(out);
      expect(envelope, isNotNull);
      expect(envelope!.verdict, VerdictKind.fail);
      expect(
        envelope.findings.any((f) => f.kind == 'analyze_error'),
        isTrue,
        reason: 'the gate diagnostics ride the findings:\n$out',
      );
      expect(envelope.details['fixtureOnly'], isTrue);
    });

    test('a real CRUD entity with no artifacts on disk still refuses '
        '(the fixture-only branch must not swallow refusals)', () async {
      final productDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities', 'product'),
      )..createSync(recursive: true);
      File(
        p.join(productDir.path, 'product.dart'),
      ).writeAsStringSync(_productSource);

      final out = await runCli(['mock', 'verify', 'Product']);

      expect(CliRunner.lastDispatchedExitCode, ExitProtocol.failure);
      expect(out, contains('missing_file'));
    });
  });
}

/// Scaffolds the fixture project: the enum entity in its per-entity folder
/// and the emitted mock-data fixture on disk (the artifact a `mock create`
/// run leaves behind).
void scaffoldEnumProject(String root) {
  final entityDir = Directory(
    p.join(root, 'lib', 'src', 'domain', 'entities', 'subscription_tier'),
  )..createSync(recursive: true);
  File(
    p.join(entityDir.path, 'subscription_tier.dart'),
  ).writeAsStringSync(_enumSource);
  final mockDir = Directory(p.join(root, 'lib', 'src', 'data', 'mock'))
    ..createSync(recursive: true);
  File(
    p.join(mockDir.path, 'subscription_tier_mock_data.dart'),
  ).writeAsStringSync(_fixtureSource);
}
