// EPIC 3 / issue #1134, lane 4 — `zfa tdd view` enforces the SAME
// vocabulary gate before any write: an out-of-vocabulary Presentation
// component token refuses the view (exit 1, subject untouched) — no
// view generator emits unchecked grid/table layout code (exit
// criterion 3).
//
//  U-1134-g3: the view-time vocabulary gate (defense in depth).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

String genStyleWidgetStub(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation).
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
Widget subject_$symbol() => throw UnimplementedError('subject_$symbol not implemented');
''';
}

/// Seed a Presentation contract declaring [components].
Future<void> seedPresentation(TddFixture fx, List<String> components) async {
  final list = File(fx.testListPath);
  await list.parent.create(recursive: true);
  await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login page shows 'Welcome back' with a sign in button | FR-001 | PENDING |

## Layer contracts

### Presentation

- `LoginSection`: ${components.map((c) => '`$c`').join(', ')}

### Domain

- `AuthRepository`: `signIn`
''');
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await Directory('${fx.root.path}/lib').create(recursive: true);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> runView({String? id = 'A-001'}) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(<String>[
      'tdd',
      'view',
      ?id,
      '--project',
      fx.root.path,
    ]);
  }

  test('U-1134-g3: an out-of-vocabulary component token refuses '
      'BEFORE any write (subject untouched)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    final stubPath = fx.subjectPathOf('A-001');
    final stub = genStyleWidgetStub('A-001');
    await File(stubPath).writeAsString(stub);
    await seedPresentation(fx, ['ShadInput', 'ShadGrid']);

    final out = await runView();

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('ShadGrid'));
    expect(out, contains('grid'));
    expect(out, contains('--> fix:'));
    expect(out, contains('zfa ui schema'));
    expect(
      await File(stubPath).readAsString(),
      stub,
      reason:
          'errors-are-an-API: a refused view writes nothing — the '
          'unchecked grid/table stand-in never lands',
    );
  });

  test(
    'U-1134-g3b: in-vocabulary tokens pass and the view scaffolds',
    () async {
      await fx.registerBehavior(
        id: 'A-001',
        description:
            "the login page shows 'Welcome back' with a sign in button",
      );
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(genStyleWidgetStub('A-001'));
      await seedPresentation(fx, ['ShadInput', 'ZfaButton']);

      final out = await runView();

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('view: behavior=A-001 outcome=scaffolded'));
      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, isNot(contains('UnimplementedError')));
    },
  );
}
