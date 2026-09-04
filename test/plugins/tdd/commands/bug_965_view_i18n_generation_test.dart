/// Tests for `zfa tdd view` under the i18n key contract (issue #965,
/// T002 — generation).
///
/// The view lane must emit `t.<key>` for scenario literals equal to a
/// declared anchor, add the host accessor import exactly when a keyed
/// surface is emitted, and scaffold missing declared keys into
/// `lib/i18n/strings.i18n.json` (merge — existing values never clobbered)
/// so the host's `/localize` gate passes mechanically. Non-keyed literals
/// keep the EN fallback byte-for-byte (zero drift for non-i18n hosts).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

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

/// Seed a test list whose Presentation contract declares the issue #965
/// key tokens.
Future<void> seedKeyedContract(TddFixture fx) async {
  final list = File(fx.testListPath);
  await list.parent.create(recursive: true);
  await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login page shows 'Sign in' with a 'Welcome back' heading | FR-001 | PENDING |

## Layer contracts

### Presentation

- `LoginSection`: `ShadInput` for email, `key: auth.signIn -> 'Sign in'`, `key: app.name -> 'ZikZak'`
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
    final args = <String>['tdd', 'view', ?id, '--project', fx.root.path];
    return runner.runCapturing(args);
  }

  test(
    'US2.AC1: an anchored presence literal renders the accessor, never '
    'the EN literal',
    () async {
      await fx.registerBehavior(
        id: 'A-001',
        description: "the login page shows 'Sign in'",
      );
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(genStyleWidgetStub('A-001'));
      await seedKeyedContract(fx);

      final out = await runView();

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, contains('Text(t.auth.signIn),'));
      expect(subject, isNot(contains("Text('Sign in')")));
    },
  );

  test('US2.AC1: the accessor import lands exactly when a keyed surface '
      'is emitted', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Sign in'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedKeyedContract(fx);

    await runView();

    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(
      subject,
      contains("import 'package:tdd_fixture/i18n/strings.g.dart';"),
    );
  });

  test('US2.AC3: a non-keyed literal keeps the EN fallback and emits no '
      'i18n import (zero drift for non-i18n hosts)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedKeyedContract(fx);

    await runView();

    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(subject, contains("Text('Welcome back')"));
    expect(subject, isNot(contains('strings.g.dart')));
    expect(subject, isNot(contains('t.auth')));
  });

  test('US2.AC2: missing declared keys are scaffolded into lib/i18n '
      '(merge — existing values never clobbered)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Sign in'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedKeyedContract(fx);
    // Pre-existing translations: app.name keeps its stored value,
    // auth.signOut is untouched, auth.signIn is missing and must land.
    final i18nFile = File(
      '${fx.root.path}/lib/i18n/strings.i18n.json',
    );
    await i18nFile.create(recursive: true);
    await i18nFile.writeAsString(
      '{"app": {"name": "ZikZak Reborn", "version": "1.0"}, '
      '"auth": {"signOut": "Sign out"}}',
    );

    await runView();

    final scaffolded = await i18nFile.readAsString();
    expect(scaffolded, contains('"signIn": "Sign in"'));
    expect(
      scaffolded,
      contains('"name": "ZikZak Reborn"'),
      reason: 'pre-existing values are never clobbered',
    );
    expect(scaffolded, contains('"signOut": "Sign out"'));
    // Deterministic shape: 2-space indent + trailing newline.
    expect(scaffolded, endsWith('}\n'));
    expect(scaffolded, contains('\n  "app"'));
  });

  test('US2.AC2: a missing lib/i18n tree is created with every declared '
      'key', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Sign in'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedKeyedContract(fx);

    await runView();

    final content = await File(
      '${fx.root.path}/lib/i18n/strings.i18n.json',
    ).readAsString();
    expect(content, contains('"auth"'));
    expect(content, contains('"signIn": "Sign in"'));
    expect(content, contains('"app"'));
    expect(content, contains('"name": "ZikZak"'));
  });

  test('an empty key table leaves the scaffold untouched (no i18n dir '
      'created for non-i18n hosts)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));

    await runView();

    expect(
      Directory('${fx.root.path}/lib/i18n').existsSync(),
      isFalse,
      reason: 'no declared keys — no i18n scaffold, no new directories',
    );
  });

  test('a malformed key token in the contract refuses before any write '
      '(errors-are-an-API)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Sign in'",
    );
    final subjectFile = File(fx.subjectPathOf('A-001'));
    await subjectFile.writeAsString(genStyleWidgetStub('A-001'));
    final before = await subjectFile.readAsString();
    final list = File(fx.testListPath);
    await list.parent.create(recursive: true);
    await list.writeAsString('''
# Test List: ${fx.featureName}

## Layer contracts

### Presentation

- `LoginSection`: `key: broken -> 'Sign in'`
''');

    final out = await runView();

    expect(exitCode, isNot(0));
    expect(out, contains('malformed i18n key token'));
    expect(out, contains('outcome=runner-error'));
    expect(
      await subjectFile.readAsString(),
      before,
      reason: 'the refusal happens before any artifact write',
    );
  });

  test('US2: determinism — identical inputs render byte-identical views '
      'and scaffold files', () async {
    Future<(String, String)> renderOnce() async {
      final fixture = await TddFixture.create();
      try {
        await Directory('${fixture.root.path}/lib').create(recursive: true);
        await fixture.registerBehavior(
          id: 'A-001',
          description: "the login page shows 'Sign in'",
        );
        await File(
          fixture.subjectPathOf('A-001'),
        ).writeAsString(genStyleWidgetStub('A-001'));
        await seedKeyedContract(fixture);
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'view',
          'A-001',
          '--project',
          fixture.root.path,
        ]);
        final subject = await File(
          fixture.subjectPathOf('A-001'),
        ).readAsString();
        final i18n = await File(
          '${fixture.root.path}/lib/i18n/strings.i18n.json',
        ).readAsString();
        return (subject, i18n);
      } finally {
        fixture.dispose();
        exitCode = 0;
      }
    }

    final (s1, i1) = await renderOnce();
    final (s2, i2) = await renderOnce();
    expect(s1, equals(s2), reason: 'the view must be deterministic');
    expect(i1, equals(i2), reason: 'the scaffold must be deterministic');
  });
}
