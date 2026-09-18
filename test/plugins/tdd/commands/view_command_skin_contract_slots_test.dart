// EPIC 3 / issue #1134, lane 1 — `zfa tdd view` honors the Skin
// Contract's `adaptive_slots` (issue #1004) as the platform layout
// declaration when the Presentation table declares no
// `adaptive_layouts` bullet: the emitted AdaptiveViewState skeleton
// carries one layout stub per CONTRACT slot, each with its slot key —
// the contract drives generation. Features declaring neither keep the
// single-layout skeleton (zero drift).
//
// Drives the public CLI surface (`zfa tdd view`) in-process against a
// TddFixture, mirroring the view_command_test.dart conventions:
//  U-1134-a4: a Skin Contract with adaptive_slots and NO Presentation
//             layout bullet makes the view emit the AdaptiveViewState
//             skeleton with one layout stub per contract slot — every
//             stub carries its slot key and the TODO placeholder.
//  U-1134-a5: a feature with NO slot declarations anywhere keeps the
//             single-layout Column skeleton (byte-stable zero drift).
//  U-1134-a6: a malformed Skin Contract (unknown slot in the contract)
//             refuses BEFORE any write (errors-are-an-API).
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

/// Seed a test list whose Presentation contract declares components but
/// NO `adaptive_layouts` bullet (the lane-1 fallback shape).
Future<void> seedPresentationWithoutSlots(TddFixture fx) async {
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

- `LoginSection`: `ShadInput` for email and password, `ShadButton` for Sign In

### Domain

- `AuthRepository`: `signIn`
''');
}

/// The feature's spec.md path.
String specPathOf(TddFixture fx) => '${fx.featureDir}/spec.md';

/// Seed the feature's spec.md with a `## Skin Contract` declaring
/// [slots] (the issue #1004 declaration).
Future<void> seedSkinContract(TddFixture fx, List<String> slots) async {
  await File(specPathOf(fx)).writeAsString('''
# Feature Specification: ${fx.featureName}

## Skin Contract

```yaml
Skin Contract:
  adaptive_slots: [${slots.join(', ')}]
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```
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

  test('U-1134-a4: the Skin Contract slots drive the AdaptiveViewState '
      'skeleton (contract-driven, no Presentation bullet)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedPresentationWithoutSlots(fx);
    await seedSkinContract(fx, ['mobile', 'macos']);

    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains('view: behavior=A-001 outcome=scaffolded'),
      reason:
          'the contract-driven skeleton still reports the '
          'deterministic machine summary',
    );
    expect(
      out,
      contains('layouts: mobile, macos — AdaptiveViewState'),
      reason: 'the contract slots are the declared layouts',
    );
    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    // The AdaptiveViewState shape: StatefulWidget + slot resolution.
    expect(subject, contains('class A001View extends StatefulWidget'));
    expect(subject, contains('_resolveSlot'));
    // One layout stub per CONTRACT slot, each carrying its slot key —
    // mobile AND macos in the same generated output.
    expect(subject, contains('class A001ViewMobileLayout'));
    expect(subject, contains("Key('a001-slot-mobile')"));
    expect(subject, contains('class A001ViewMacosLayout'));
    expect(subject, contains("Key('a001-slot-macos')"));
    // The composed declared surfaces ride every stub (issue #1142's
    // shared derivation — the paired test asserts the same literals).
    expect(subject, contains('TODO: Implement A001View mobile layout'));
    expect(subject, contains('TODO: Implement A001View macos layout'));
  });

  test('U-1134-a5: no slot declarations anywhere → the single-layout '
      'Column skeleton (zero drift)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedPresentationWithoutSlots(fx);
    // No Skin Contract section in spec.md either.
    await File(specPathOf(fx)).writeAsString('# spec\n');

    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('layouts: no platform slots declared'));
    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(
      subject,
      contains('class A001View extends StatelessWidget'),
      reason: 'the single-layout skeleton is unchanged',
    );
    expect(subject, isNot(contains('AdaptiveViewState')));
    expect(subject, isNot(contains('slotKey')));
  });

  test('U-1134-a6: a malformed Skin Contract slot refuses BEFORE any '
      'write', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    final stubPath = fx.subjectPathOf('A-001');
    final stub = genStyleWidgetStub('A-001');
    await File(stubPath).writeAsString(stub);
    await seedPresentationWithoutSlots(fx);
    await seedSkinContract(fx, ['mobile', 'watch']);

    final out = await runView();

    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('watch'));
    expect(out, contains('--> fix:'));
    expect(
      await File(stubPath).readAsString(),
      stub,
      reason: 'errors-are-an-API: a refused view writes nothing',
    );
  });
}
