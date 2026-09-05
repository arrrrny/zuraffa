// Issue #1000 ([ZIKZAK-REBUILD] spec template [CORE]/[SKIN] lane markers +
// AdaptiveViewSlots): `zfa tdd plan` on a spec whose `## Lanes` section
// declares the engine/skin split emits `tdd/04-ENGINE.md` +
// `tdd/04-SKIN.md` + `tdd/04-CONTRACT.md` (no `04-test-list.md`), and
// `tdd/test-list.md` becomes the meta-index. A spec without `## Lanes`
// keeps the legacy single-file shape byte-for-byte.
//
// RED phase: plan knows nothing about lanes — the split assertions fail.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

const String feature = '004-login-ui';

/// The canonical 004-login-ui fixture (issue #1000's example): A1/A2 + the
/// six unit behaviors are CORE, W1-W4 are SKIN (hand-declared skin rows),
/// A3 — the navigation acceptance — is BOTH.
const String lanesSpec = '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to deal_list

## Functional Requirements

- **FR-001**: The system shall validate the email format through the login validator.
- **FR-002**: The system shall hash the password with the credential hasher.
- **FR-003**: The system shall start a session and persist the auth token through the session repository.
- **FR-004**: The system shall read the current session through the session repository.
- **FR-005**: The system shall reject an expired session.
- **FR-006**: The system shall resolve the deal_list route for the completed session.

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1-U6]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W4]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```
''';

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_lanes_1000_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String spec) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  }

  List<String> planArgs() => ['tdd', 'plan', '--project', tmpDir.path, feature];

  File laneFile(String name) => File(p.join(tddDir, name));

  group('issue #1000 — plan splits a Lanes-declaring spec', () {
    test('zfa tdd plan $feature emits 04-ENGINE.md, 04-SKIN.md, and '
        '04-CONTRACT.md (no 04-test-list.md)', () async {
      await seedSpec(lanesSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0, reason: 'plan succeeded');
      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isTrue,
        reason: 'engine plan emitted',
      );
      expect(
        laneFile('04-SKIN.md').existsSync(),
        isTrue,
        reason: 'skin plan emitted',
      );
      expect(
        laneFile('04-CONTRACT.md').existsSync(),
        isTrue,
        reason: 'engine/skin contract emitted',
      );
      expect(
        laneFile('04-test-list.md').existsSync(),
        isFalse,
        reason: 'the monolithic 04-test-list.md is gone',
      );
      expect(
        laneFile('test-list.md').existsSync(),
        isTrue,
        reason: 'the legacy filename lives on as the meta-index',
      );
    });

    test('04-ENGINE.md contains zero package:flutter references', () async {
      await seedSpec(lanesSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0);
      final engine = await laneFile('04-ENGINE.md').readAsString();
      // Built from pieces so this test's own source is not a false
      // positive for the greps that scan the repo (see the TUI
      // no_flutter_import_test precedent).
      final forbidden = 'package:${'flutter'}';
      expect(
        engine.contains(forbidden),
        isFalse,
        reason: 'the engine lane is pure Dart by construction',
      );
    });

    test(
      '04-SKIN.md contains the AdaptiveViewSlots declared in the spec',
      () async {
        await seedSpec(lanesSpec);
        await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
        expect(exitCode, 0);
        final skin = await laneFile('04-SKIN.md').readAsString();
        for (final slot in ['mobile', 'ios', 'android', 'macos']) {
          expect(
            skin.contains(slot),
            isTrue,
            reason: 'AdaptiveViewSlot "$slot" rendered in the skin plan',
          );
        }
        expect(
          skin.toLowerCase().contains('adaptive view slots'),
          isTrue,
          reason: 'the AdaptiveViewSlots section is present',
        );
      },
    );

    test('engine rows are CORE+BOTH; skin rows are SKIN+BOTH with the '
        'hand-declared W1-W4', () async {
      await seedSpec(lanesSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0);
      final engine = await laneFile('04-ENGINE.md').readAsString();
      final skin = await laneFile('04-SKIN.md').readAsString();

      // Engine: A1, A2 (CORE) + U1-U6 (CORE) + A3 (BOTH seam).
      for (final id in ['A1', 'A2', 'A3', 'U1', 'U2', 'U3', 'U4', 'U5', 'U6']) {
        expect(engine.contains('| $id |'), isTrue, reason: '$id in engine');
      }
      expect(engine.contains('| W1 |'), isFalse, reason: 'W rows are skin');

      // Skin: W1-W4 (SKIN) + A3 (BOTH seam); engine-only rows absent.
      for (final id in ['W1', 'W2', 'W3', 'W4', 'A3']) {
        expect(skin.contains('| $id |'), isTrue, reason: '$id in skin');
      }
      expect(skin.contains('| U1 |'), isFalse, reason: 'units are engine');
    });

    test('test-list.md becomes the meta-index and TestListReader resolves '
        'every row (BOTH ids once)', () async {
      await seedSpec(lanesSpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0);

      final meta = await laneFile('test-list.md').readAsString();
      expect(
        meta.toLowerCase().contains('meta-index'),
        isTrue,
        reason: 'the meta-index identifies itself',
      );
      expect(
        meta.contains('| A1 |'),
        isFalse,
        reason: 'the meta-index carries no behavior rows',
      );

      final rows = await TestListReader(featureDir).read();
      final ids = rows.map((r) => r.id).toList();
      // A3 lives in BOTH files but resolves once (engine copy first).
      expect(ids.where((id) => id == 'A3'), hasLength(1));
      expect(
        ids.toSet().containsAll([
          'A1',
          'A2',
          'A3',
          'U1',
          'U2',
          'U3',
          'U4',
          'U5',
          'U6',
          'W1',
          'W2',
          'W3',
          'W4',
        ]),
        isTrue,
        reason: 'every lane behavior resolves through the reader',
      );
      // W rows are skin (widget) kind — their gen pair is a testWidgets
      // pair, the skin surface.
      expect(
        rows.where((r) => r.id.startsWith('W')).map((r) => r.kind).toSet(),
        {BehaviorKind.widget},
      );
    });
  });

  group('issue #1000 — noFlutter guard (plan-enforced)', () {
    test('a CORE behavior whose row references package:flutter is refused '
        'with NO artifacts', () async {
      final spec = lanesSpec.replaceFirst(
        'The system shall validate the email format through the login '
            'validator.',
        'The system shall validate the email format by importing '
            'package:flutter/material.dart widgets.',
      );
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.toLowerCase().contains('flutter'),
        isTrue,
        reason: 'the refusal names the flutter reference',
      );
      expect(
        out.contains('U1'),
        isTrue,
        reason: 'the refusal names the offending behavior',
      );
      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isFalse,
        reason: 'no artifacts on refusal',
      );
      expect(
        laneFile('04-SKIN.md').existsSync(),
        isFalse,
        reason: 'no artifacts on refusal',
      );
      expect(
        laneFile('test-list.md').existsSync(),
        isFalse,
        reason: 'no artifacts on refusal',
      );
    });

    test(
      'a CORE behavior routed widget-kind (Flutter-only kind) is refused',
      () async {
        // A1's prose becomes UI-observable — the fallback classifier
        // routes it widget-kind, but the Lanes section pins it CORE.
        final spec = lanesSpec.replaceFirst(
          '**Then** the session starts with the authenticated user',
          '**Then** the login form renders the authenticated user badge',
        );
        await seedSpec(spec);
        final out = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(planArgs());
        expect(exitCode, 2, reason: out);
        expect(
          out.contains('A1'),
          isTrue,
          reason: 'the refusal names the offending behavior',
        );
        expect(
          laneFile('04-ENGINE.md').existsSync(),
          isFalse,
          reason: 'no artifacts on refusal',
        );
      },
    );

    test('a spec-derived behavior no lane declares is refused with the '
        'declaration to add', () async {
      final spec = lanesSpec.replaceFirst(
        'behaviors: [A1, A2, U1-U6]',
        'behaviors: [A1, A2, U1-U5]',
      );
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.contains('U6'),
        isTrue,
        reason: 'the undeclared behavior is named',
      );
      expect(
        laneFile('04-ENGINE.md').existsSync(),
        isFalse,
        reason: 'no artifacts on refusal',
      );
    });
  });

  group('issue #1000 — legacy shape unchanged (hard constraint)', () {
    test('a spec without ## Lanes emits the single legacy test-list.md and '
        'no 04-* lane files', () async {
      final legacySpec = lanesSpec.substring(0, lanesSpec.indexOf('## Lanes'));
      await seedSpec(legacySpec);
      await CliRunner(exitOnCompletion: false).runCapturing(planArgs());
      expect(exitCode, 0);
      expect(
        laneFile('test-list.md').existsSync(),
        isTrue,
        reason: 'legacy single-file plan',
      );
      for (final name in [
        '04-ENGINE.md',
        '04-SKIN.md',
        '04-CONTRACT.md',
        '04-test-list.md',
      ]) {
        expect(
          laneFile(name).existsSync(),
          isFalse,
          reason: '$name must not exist for a legacy spec',
        );
      }
      final rows = await TestListReader(featureDir).read();
      expect(
        rows.map((r) => r.id).toSet(),
        containsAll(['A1', 'A2', 'A3', 'U1', 'U2', 'U3', 'U4', 'U5', 'U6']),
      );
    });
  });
}
