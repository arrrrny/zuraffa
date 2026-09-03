@Tags(['slow'])
// A2/T-review (feature 071): `zfa tdd make` wires parsed spec
// declarations into the planner — a declared entity contract row routes
// the entity pipeline with the DECLARED entity name at the CLI surface,
// even when the description would bait the legacy description-keyed
// CRUD branch ("repository service ..."). The strict-refusal pin covers
// the refusal path; this pin covers the happy path. Issue #951.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

List<String> makeArgs(TddFixture fx, {required String zfaBin}) => [
  'tdd',
  'make',
  '--project',
  fx.root.path,
  '--feature',
  fx.featureName,
  '--zfa-bin',
  zfaBin,
];

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  test(
    'a declared entity row routes the entity pipeline with the '
    'declared name at the make surface (description prose ignored)',
    () async {
      const description = 'the invoice repository service persists invoices';
      await fx.seedTestList([
        (
          id: 'U-1',
          description: description,
          traces: 'Product',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      // The spec declares the entity the behavior routes to — the bait
      // prose names a DIFFERENT entity (invoice) and the CRUD keyword
      // ("repository"), both of which must lose to the declaration.
      final featureDir = Directory('${fx.root.path}/specs/${fx.featureName}')
        ..createSync(recursive: true);
      File('${featureDir.path}/spec.md').writeAsStringSync('''
**Template Version**: `zuraffa-1.0`

# Spec: ${fx.featureName}

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| Product | name, price | the declared catalog entity |

## Acceptance Scenarios

1. **Given** a catalog **When** queried **Then** returns 42 when invoked with no args
''');
      // Certified red: the subject-driven test passes only when the fake
      // `tdd wire` step's side effect writes the implemented subject.
      await fx.seedCertifiedRed(
        id: 'U-1',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U-1', description),
        subjectContent: TddFixture.subjectReturning('U-1', 0),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd wire': fx.overwriteSubjectCommands(
            'U-1',
            TddFixture.subjectReturning('U-1', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(makeArgs(fx, zfaBin: zfaBin));

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains('make: behavior=U-1 outcome=green feature=${fx.featureName}'),
      );
      // The DECLARED entity pipeline ran: the entity name comes from the
      // contract row (Product), never from the bait prose (invoice) or a
      // slugified id — and no description-keyed `make <slug>` dispatched.
      final log = await fx.readFakeZfaLog();
      expect(log, isNotEmpty);
      expect(log.first, contains('entity create -n Product'));
      expect(
        log.join('\n'),
        contains('tdd wire U-1 --entity Product'),
        reason: 'the wire step targets the declared entity',
      );
      expect(
        log.join('\n'),
        isNot(contains('-n Invoice')),
        reason: 'the bait prose never names the generated entity',
      );
    },
  );
}
