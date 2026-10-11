/// Tests for the view-side localization audit (issue #1141, U3+U4+U5).
///
/// #965's `untracedHardcodedStrings` detector existed as a library
/// function with no caller. This spec wires it into `zfa tdd view` as a
/// pre-write gate (errors-are-an-API: a refused view leaves the stub
/// untouched) and adds the keyed-host half — a quoted literal that IS a
/// declared key's anchor is a hardcoded-key violation (the key contract
/// requires the accessor `t.<key>`), which is exactly what a generator
/// degraded to EN emission would render.
///
/// RED phase: the audit does not exist — the unit-level class is a
/// compile error and the CLI refuses nothing.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/ui_ledger_projection.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

import '../helpers/tdd_fixture.dart';

/// The gen-shaped widget stub SubjectWriter emits for a widget-kind
/// behavior (bug #830).
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

void main() {
  group('bug 1141 U4 (unit): UiViewAudit — the audit contract', () {
    final keyTable = I18nKeyTable.of([
      const I18nKeyContract(key: 'auth.signIn', anchor: 'Sign in'),
      const I18nKeyContract(key: 'app.name', anchor: 'ZikZak'),
    ]);
    final ledger = UiLedgerBuilder.derive(
      declared: [
        ...keyTable.toDeclaredSurfaces(
          proversByKey: const {
            'auth.signIn': ['A-001'],
          },
        ),
        const DeclaredSurface(
          surface: 'Welcome back',
          kind: UiSurfaceKind.text,
          declaredProvers: ['A-002'],
        ),
      ],
      greenBehaviors: const {'A-001'},
    );

    test('a keyed view is clean: accessors are code identity, never '
        'flagged', () {
      const view = '''
Column(
  children: [
    Text(t.auth.signIn),
    Text(t.app.name),
  ],
)''';
      final result = UiViewAudit.audit(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(result.violations, isEmpty);
      expect(result.quotedUserFacingStrings, isEmpty);
    });

    test('an untraced hardcoded string is an untraced-surface violation '
        'with a fix line', () {
      const view = '''
Column(
  children: [
    Text('Some hardcode'),
  ],
)''';
      final result = UiViewAudit.audit(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      expect(result.violations, hasLength(1));
      final violation = result.violations.single;
      expect(violation.kind, UiViewAuditViolationKind.untracedSurface);
      expect(violation.literal, 'Some hardcode');
      expect(violation.message, contains('--> fix:'));
    });

    test('a declared anchor rendered as a quoted literal is a '
        'hardcoded-key violation naming the required accessor', () {
      // The degraded-generator shape (0965 mutant M3): the keyed surface
      // fell back to the EN literal. The anchor TRACES (0965 semantics)
      // but the key contract requires the accessor — the audit refuses.
      const view = '''
Column(
  children: [
    Text('Sign in'),
  ],
)''';
      final result = UiViewAudit.audit(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
      );
      final violation = result.violations.singleWhere(
        (v) => v.kind == UiViewAuditViolationKind.hardcodedKey,
      );
      expect(violation.literal, 'Sign in');
      expect(violation.message, contains('t.auth.signIn'));
      expect(violation.message, contains('--> fix:'));
    });

    test('a traced text literal passes; button children are user-facing '
        'too', () {
      const cleanView = '''
Column(
  children: [
    Text('Welcome back'),
  ],
)''';
      expect(
        UiViewAudit.audit(
          viewSource: cleanView,
          ledger: ledger,
          anchorToKey: keyTable.anchorToKey,
        ).violations,
        isEmpty,
      );

      const dirtyView = '''
Column(
  children: [
    ElevatedButton(
      onPressed: () {},
      child: Text('mystery action'),
    ),
  ],
)''';
      expect(
        UiViewAudit.audit(
          viewSource: dirtyView,
          ledger: ledger,
          anchorToKey: keyTable.anchorToKey,
        ).violations.map((v) => v.literal),
        ['mystery action'],
      );
    });

    test('no declared keys — the audit reduces to untraced detection '
        '(zero drift for non-i18n hosts)', () {
      const view = '''
Column(
  children: [
    Text('Welcome back'),
  ],
)''';
      final result = UiViewAudit.audit(viewSource: view, ledger: ledger);
      expect(result.violations, isEmpty);
    });

    test('marker literals (the #939 behavior-id marker) stay traceable', () {
      const view = '''
Column(
  children: [
    Text('A-001'),
  ],
)''';
      final result = UiViewAudit.audit(
        viewSource: view,
        ledger: ledger,
        anchorToKey: keyTable.anchorToKey,
        markerLiterals: const ['A-001'],
      );
      expect(result.violations, isEmpty);
    });
  });

  group('bug 1141 U3+U5 (CLI): zfa tdd view audits before any write', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create();
      await Directory('${fx.root.path}/lib').create(recursive: true);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    Future<String> runView({String? id = 'A-001'}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'view',
        ?id,
        '--project',
        fx.root.path,
      ]);
    }

    test('U3: a literal that traces to no declared row refuses BEFORE the '
        'write (errors-are-an-API)', () async {
      // The record's description quotes 'Session started', but the
      // DECLARED test list carries no row quoting it — drift between
      // the composition source and the declared contract surfaces as
      // an untraced-surface violation.
      await fx.registerBehavior(
        id: 'A-001',
        description: "the login view shows 'Session started'",
      );
      final subjectFile = File(fx.subjectPathOf('A-001'));
      await subjectFile.writeAsString(genStyleWidgetStub('A-001'));
      final before = await subjectFile.readAsString();
      final list = File(fx.testListPath);
      await list.parent.create(recursive: true);
      await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login view renders the form | FR-001 | PENDING |
''');

      final out = await runView();

      expect(exitCode, isNot(0), reason: 'out: $out');
      expect(out, contains('untraced-surface violation'));
      expect(out, contains('Session started'));
      expect(out, contains('--> fix:'));
      expect(
        await subjectFile.readAsString(),
        before,
        reason: 'the refusal happens before any artifact write',
      );
      expect(
        Directory('${fx.root.path}/lib/i18n').existsSync(),
        isFalse,
        reason: 'no i18n scaffold from a refused view',
      );
    });

    test('U5: zero drift — a scenario-literal view with no declared keys '
        'stays scaffolded, exit 0 (the non-i18n fallback contract)', () async {
      await fx.registerBehavior(
        id: 'A-001',
        description: "the login page shows 'Welcome back'",
      );
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(genStyleWidgetStub('A-001'));

      final out = await runView();

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, contains("Text('Welcome back')"));
      expect(out, contains('outcome=scaffolded'));
    });

    test('the keyed regeneration passes the audit mechanically (clean audit '
        'line, zero quoted user-facing strings)', () async {
      await fx.registerBehavior(
        id: 'A-001',
        description: "the login page shows 'Sign in'",
      );
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(genStyleWidgetStub('A-001'));
      final list = File(fx.testListPath);
      await list.parent.create(recursive: true);
      await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login page shows 'Sign in' | FR-001 | PENDING |

## Layer contracts

### Presentation

- `LoginSection`: `ShadInput` for email, `key: auth.signIn -> 'Sign in'`
''');

      final out = await runView();

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('i18n audit: clean'));
      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, contains('Text(t.auth.signIn),'));
      expect(
        UiLedgerBuilder.quotedUserFacingStrings(subject),
        isEmpty,
        reason: 'zero hardcoded user-facing strings in the keyed view',
      );
    });
  });
}
