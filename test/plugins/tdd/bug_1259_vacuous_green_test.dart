@Tags(['slow'])
// Bug #1259 — the engine (unit) lane certifies vacuous greens.
//
// `zfa tdd gen` for a unit behavior derives a subject signature
// disconnected from the spec's declared Layer Contracts, and the
// generated test's only assertion is the UnimplementedError guard — a
// placeholder subject that returns a dummy value flips the test green
// without implementing anything, yet the receipt reports complete.
//
// Remediation pinned here (from the assessment):
//   1. `make` refuses vacuous greens — a unit test whose assertion set
//      is only the UnimplementedError guard cannot certify green (the
//      unit-lane analogue of the widget lane's scaffolded refusal,
//      issue #912 defect 3). The red surface can START at the guard,
//      but green requires at least one assertion on the observable
//      outcome named by the behavior description.
//   2. `gen` derives the subject signature from the spec's declared
//      Layer Contracts (params from the request entity, return from
//      the result entity) instead of inventing shapes.
//   3. The declared signature resolution covers DOMAIN/DATA layer rows
//      (`AuthRepo: login(AuthRequest) -> User`), not just function
//      rows, so `func` scaffolds the declared shape.
//
// Test map:
//   U1 — make refuses a passing guard-only unit test (the func-scaffold
//        dummy class): exit 1, outcome=vacuous-green, no green evidence.
//   U2 — the same unit test WITH an observable-outcome assertion
//        certifies green: the refusal keys on the assertion set.
//   U3 — acceptance rows keep the legacy skip transition (unit-lane
//        scope; the acceptance composition lane is deferred by design).
//   U4 — gen derives the contract signature for a domain-traced unit
//        behavior (entity return): no invented `int subject()` shape,
//        declared contract provenance in the header, honest red kept,
//        the paired test carries the vacuous-guard marker.
//   U5 — gen for a scalar-declared contract emits the declared return
//        type + a typed outcome assertion (not the guard).
//   U6 — func scaffolds the declared contract shape (params preserved,
//        entity return stays red) instead of refusing the contract
//        stub as an unrecognized shape.
//   U7 — the routing resolver resolves signatures declared on
//        DOMAIN rows (the issue's `AuthRepo` under `**Domain**:`).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/routing_resolver.dart';

import 'helpers/tdd_fixture.dart';

/// The gen-emitted guard-only unit test (the exact vacuity shape from
/// the issue): the capture + the UnimplementedError guard, nothing else.
String guardOnlyTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id — $description', () {
    final result = (() {
      try {
        return subject.$symbol();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';
}

/// The same test plus one observable-outcome assertion — the shape green
/// certification must REQUIRE (issue #1259 remediation).
String outcomeAssertedTest(String id, String description) =>
    guardOnlyTest(id, description).replaceFirst(
      '    expect(result, isNot(isA<UnimplementedError>()));',
      '    expect(result, isNot(isA<UnimplementedError>()));\n'
          '    expect(result, isNotNull);',
    );

/// The acceptance-lane capture shape (the scenario-runner call returns
/// null through the capture) with the guard as the only assertion.
String guardOnlyAcceptanceTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id — $description', () {
    final Object? result = (() {
      try {
        subject.$symbol();
        return null;
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';
}

/// A func-scaffolded subject (the post-`tdd func` state): a dummy value
/// return — zero Session/AuthRepo/User code anywhere (the issue's
/// vacuous-green trigger).
String scaffoldedSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

int $symbol() {
  return 0;
}
''';
}

/// An implemented acceptance scenario runner (no throw).
String scaffoldedVoidSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

void $symbol() {}
''';
}

/// Gen writes its artifacts namespaced by feature slug (bug #827):
/// `test/tdd/<feature>/<snake>_test.dart` +
/// `lib/tdd/<feature>/<snake>_subject.dart` — the registry record is the
/// single path contract, so the tests read through it.
Future<String> genSubjectOf(TddFixture fx, String id) async {
  final record = await fx.registryRecordOf(id);
  return File(record['subject_path'] as String).readAsString();
}

Future<String> genTestOf(TddFixture fx, String id) async {
  final record = await fx.registryRecordOf(id);
  return File(record['test_path'] as String).readAsString();
}

/// The spec declaring the issue's login feature: Key Entities
/// (`AuthRequest`, `User`) and the DOMAIN layer contract
/// `AuthRepo: login(AuthRequest) -> User`.
const loginFeatureSpec = '''
# Login Feature

### Key Entities

| Entity | Fields | Purpose |
| --- | --- | --- |
| AuthRequest | `id: String` | the login request |
| User | `email: String` | the authenticated user |

### Layer Contracts

**Domain**:
- `AuthRepo`: `login(AuthRequest) -> User`
''';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1259 — make refuses vacuous greens (unit lane)', () {
    test('U1: a unit test whose only assertion is the UnimplementedError '
        'guard cannot certify green — even when it passes', () async {
      const description =
          'the system MUST save a Session when the form is committed';
      await fx.seedTestList([
        (
          id: 'B-1259',
          description: description,
          traces: 'FR-100',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // The vacuous-green state: certified red, then the func scaffold
      // rewrote the subject to a dummy return — the guard-only test
      // now PASSES.
      await fx.seedCertifiedRed(
        id: 'B-1259',
        description: description,
        subjectContent: scaffoldedSubject('B-1259'),
        testContent: guardOnlyTest('B-1259', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'B-1259', '--project', fx.root.path]);

      expect(exitCode, 1, reason: 'a vacuous green must not certify: $out');
      expect(out, contains('outcome=vacuous-green'));
      expect(out, contains('UnimplementedError guard'));
      final log = await File(fx.cycleLogPath).readAsString();
      expect(
        log,
        isNot(contains('## Cycle: B-1259 (green)')),
        reason: 'no green evidence may be appended for a vacuous green',
      );
    });

    test('U2: the same unit test WITH an observable-outcome assertion '
        'certifies green — the refusal keys on the assertion set', () async {
      const description =
          'the system MUST save a Session when the form is committed';
      await fx.seedTestList([
        (
          id: 'B-1259',
          description: description,
          traces: 'FR-100',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'B-1259',
        description: description,
        subjectContent: scaffoldedSubject('B-1259'),
        testContent: outcomeAssertedTest('B-1259', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'B-1259', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'));
    });

    test('U3: acceptance rows keep the legacy skip transition — the '
        'refusal is scoped to the unit lane', () async {
      const description = 'the login scenario completes';
      await fx.seedTestList([
        (
          id: 'A-1259',
          description: description,
          traces: 'FR-100',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A-1259',
        description: description,
        subjectContent: scaffoldedVoidSubject('A-1259'),
        testContent: guardOnlyAcceptanceTest('A-1259', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A-1259', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'));
    });
  });

  group('issue #1259 — gen derives the signature from the declared Layer '
      'Contracts', () {
    test('U4: a domain-contract-traced unit behavior gets a '
        'contract-derived subject, never an invented shape', () async {
      await fx.seedTestList([
        (
          id: 'U-100',
          description:
              'the system MUST save a Session when the form is committed',
          traces: 'AuthRepo.login',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await Directory(p.join(fx.featureDir)).create(recursive: true);
      await File(
        p.join(fx.featureDir, 'spec.md'),
      ).writeAsString(loginFeatureSpec);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U-100', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await genSubjectOf(fx, 'U-100');
      expect(
        subject,
        isNot(contains('int subject_u_100()')),
        reason: 'the invented no-arg int shape IS the bug (issue #1259)',
      );
      expect(
        subject,
        contains('login(AuthRequest) -> User'),
        reason: 'the declared contract travels in the provenance header',
      );
      expect(
        subject,
        contains('UnimplementedError'),
        reason: 'honest red is preserved',
      );
      final test = await genTestOf(fx, 'U-100');
      expect(
        test,
        contains('vacuous-guard'),
        reason:
            'an entity-return contract has no mechanical outcome assertion '
            'yet — the test carries the marker so make refuses green until '
            'a real outcome assertion lands',
      );
    });

    test('U5: a scalar-declared contract emits the declared return type '
        'and a typed outcome assertion — not the guard', () async {
      await fx.seedTestList([
        (
          id: 'U-110',
          description: 'the label renders the template',
          traces: 'Formatter.label',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await Directory(p.join(fx.featureDir)).create(recursive: true);
      await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
# Formatter

### Layer Contracts

**Function**:
- `Formatter`: `label() -> bool`
''');

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U-110', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await genSubjectOf(fx, 'U-110');
      expect(
        subject,
        contains('bool subject_u_110()'),
        reason: 'the declared return type is the subject signature',
      );
      expect(subject, contains('UnimplementedError'));
      final test = await genTestOf(fx, 'U-110');
      expect(
        test,
        contains('expect(result, isA<bool>())'),
        reason: 'the declared scalar outcome is asserted mechanically',
      );
      expect(
        test,
        isNot(contains('vacuous-guard')),
        reason: 'a typed outcome assertion is present — not guard-only',
      );
    });

    test('U6: func scaffolds the declared contract shape — params '
        'preserved, entity return stays red', () async {
      await fx.seedTestList([
        (
          id: 'U-100',
          description:
              'the system MUST save a Session when the form is committed',
          traces: 'AuthRepo.login',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await Directory(p.join(fx.featureDir)).create(recursive: true);
      await File(
        p.join(fx.featureDir, 'spec.md'),
      ).writeAsString(loginFeatureSpec);
      await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'U-100', '--project', fx.root.path]);

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'func', 'U-100', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await genSubjectOf(fx, 'U-100');
      expect(
        subject,
        contains('UnimplementedError'),
        reason:
            'a declared entity-return contract cannot be scaffolded to a '
            'dummy value — the honest scaffold stays red (issue #920)',
      );
      expect(
        subject,
        contains('login(AuthRequest) -> User'),
        reason: 'the declared contract provenance survives the rewrite',
      );
    });

    test('U7: the routing resolver resolves signatures declared on DOMAIN '
        'rows (the issue\'s AuthRepo under **Domain**:)', () {
      final result = const RoutingResolver().resolve(
        row: const RoutingRow(behaviorId: 'U1', traces: ['AuthRepo.login']),
        declarations: SpecDeclarations(
          contractRows: {
            'AuthRepo': ContractRowDecl(
              name: 'AuthRepo',
              kind: ContractRowKind.domain,
              signatures: [
                const Signature(
                  name: 'login',
                  parameters: ['AuthRequest'],
                  returnType: 'User',
                ),
              ],
              specLine: 12,
            ),
          },
        ),
      );
      expect(result, isA<RoutingDecision>());
      final d = result as RoutingDecision;
      expect(d.kind, BehaviorKind.unit);
      expect(d.signature, isNotNull);
      expect(d.signature!.name, 'login');
      expect(d.signature!.returnType, 'User');
      expect(d.signature!.parameters, ['AuthRequest']);
    });
  });
}
