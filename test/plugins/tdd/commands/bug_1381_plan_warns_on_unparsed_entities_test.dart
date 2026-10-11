// Issue #1370/#1373-style harness: a fixture spec whose `## Key Entities`
// section yields ZERO entities (a 1-column table no grammar accepts) —
// plan must print the #1381 warning naming the section instead of
// silently writing a test list without entities (the cert gate would
// then pass trivially).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: '1381-warn');
    // A Key Entities section whose table no grammar accepts.
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString('''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** a seeded entity **When** the run starts **Then** the entity is visible

## Functional Requirements

- **FR-001**: The system shall show the seeded entity.

## Key Entities

| name |
| ---- |
| Login |
''');
  });

  tearDown(() {
    exitCode = 0;
    if (fx.root.existsSync()) fx.root.deleteSync(recursive: true);
  });

  test('plan warns when the declared Key Entities section yields zero '
      'entities (issue #1381)', () async {
    final runner = CliRunner(exitOnCompletion: false);
    final output = await runner.runCapturing([
      'tdd',
      'plan',
      fx.featureName,
      '--project',
      fx.root.path,
    ]);

    expect(output, contains('## Key Entities'), reason: output);
    expect(output, contains('no entities were extracted'), reason: output);
  });
}
