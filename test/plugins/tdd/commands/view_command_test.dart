// Fast unit tests for `ViewCommand` — the deterministic view-builder
// generator surface for widget-kind behaviors (issue #939).
//
// Drives the public CLI surface (`zfa tdd view`) in-process against a
// TddFixture carrying the gen artifacts (registry record + the exact
// UnimplementedError view-builder stub SubjectWriter emits for the
// widget kind, bug #830). Mirrors the func_command_test.dart conventions:
//   U-V1: a gen-shaped widget stub is rewritten to the view-builder + a
//         StatelessWidget skeleton composed of the scenario literals
//         (Text) and the Presentation contract's declared components
//         (TextField for *Input, ElevatedButton for *Button).
//   U-V2: idempotent — an already-implemented view-builder reports
//         already-implemented and exits 0.
//   U-V3: a missing subject file is a hard runner-error (gen first).
//   U-V4: an unknown behavior id is a hard runner-error.
//   U-V5: an unrecognized UnimplementedError shape is refused, never
//         guessed at.
//   U-V6: the paired test file is never touched (044 ownership).
//   U-V7: no Presentation contract → the literal-only composition, still
//         scaffolded and deterministic.
//   U-V8: determinism — identical inputs render byte-identical views.
//   U-V9: only the matched stub declaration is replaced; surrounding
//         source content is preserved.
//  U-V10: description-quoted literals become Text children (the same
//         literals behavior_test_writer derives find.text assertions
//         from, issue #912 defect 3) — the loop's REACH-green contract.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The gen-shaped widget stub SubjectWriter emits for a widget-kind
/// behavior (bug #830): a view-builder function returning the feature
/// Widget, throwing UnimplementedError (honest red).
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

/// Seed the Presentation layer contract the zuraffa-1.0 template
/// declares (the same section plan writes from `### Layer Contracts`).
Future<void> seedPresentationContract(TddFixture fx) async {
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

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // The subject's parent dir (registerBehavior records lib/ paths but
    // the fixture only creates specs/ and bin/).
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
    'U-V1: a gen-shaped widget stub is rewritten to the view-builder + '
    'minimal view composed from the declared contract and literals',
    () async {
      await fx.registerBehavior(
        id: 'A-001',
        description:
            "the login page shows 'Welcome back' with a sign in button",
      );
      await File(
        fx.subjectPathOf('A-001'),
      ).writeAsString(genStyleWidgetStub('A-001'));
      await seedPresentationContract(fx);

      final out = await runView();

      expect(exitCode, 0, reason: 'out: $out');
      expect(
        out,
        contains(
          'view: behavior=A-001 outcome=scaffolded feature=${fx.featureName}',
        ),
      );
      final subject = await File(fx.subjectPathOf('A-001')).readAsString();
      expect(subject, isNot(contains('UnimplementedError')));
      // The view-builder keeps the stub's function name and returns the
      // skeleton view.
      expect(subject, contains('Widget subject_a_001() => A001View();'));
      // The skeleton composes the DECLARED components (issue #939): the
      // Presentation contract's tokens map to deterministic stand-ins —
      // ShadInput → TextField, ShadButton → ElevatedButton labeled with
      // the declared token (traceable, handcraft-seam editable).
      expect(subject, contains('class A001View extends StatelessWidget {'));
      expect(subject, contains('TextField(),'));
      expect(subject, contains('ElevatedButton(onPressed: () {}'));
      expect(subject, contains("Text('ShadButton')"));
      // Domain contracts never leak into the Presentation skeleton.
      expect(subject, isNot(contains('AuthRepository')));
    },
  );

  test('U-V10: description-quoted literals become Text children (the '
      "paired widget test's find.text targets)", () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedPresentationContract(fx);

    await runView();

    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    // The literal the generated test's finder asserts must be RENDERED.
    expect(subject, contains("Text('Welcome back')"));
  });

  test(
    'U-V2: an already-implemented view-builder is a no-op '
    '(already-implemented, exit 0) so a resumed pipeline stays green',
    () async {
      await fx.registerBehavior(
        id: 'A-001',
        description: 'the login page renders',
      );
      await File(fx.subjectPathOf('A-001')).writeAsString('''
library;

import 'package:flutter/material.dart';

Widget subject_a_001() => const SizedBox.shrink();
''');
      final before = await File(fx.subjectPathOf('A-001')).readAsString();

      final out = await runView();

      expect(exitCode, 0, reason: 'out: $out');
      expect(
        out,
        contains(
          'view: behavior=A-001 outcome=already-implemented '
          'feature=${fx.featureName}',
        ),
      );
      expect(await File(fx.subjectPathOf('A-001')).readAsString(), before);
    },
  );

  test('U-V3: a missing subject file is a hard runner-error', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: 'the login page renders',
      writeTestFile: false,
    );

    final out = await runView();

    expect(exitCode, isNot(0));
    expect(out, contains('runner-error'));
    expect(out, contains('missing subject file'));
  });

  test('U-V4: an unknown behavior id is a hard runner-error', () async {
    final out = await runView(id: 'A-999');

    expect(exitCode, isNot(0));
    expect(out, contains('unknown behavior id "A-999"'));
    expect(out, contains('outcome=runner-error'));
  });

  test('U-V5: an unrecognized UnimplementedError shape is refused, never '
      'guessed at', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: 'the login page renders',
    );
    await File(fx.subjectPathOf('A-001')).writeAsString('''
library;

Widget subject_a_001() {
  throw UnimplementedError('hand-written shape');
}
''');

    final out = await runView();

    expect(exitCode, isNot(0));
    expect(out, contains('unrecognized shape'));
    expect(out, contains('outcome=runner-error'));
  });

  test('U-V6: the paired test file is never touched (044 ownership)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    final testPath = fx.testPathOf('A-001');
    final before = await File(testPath).readAsString();

    await runView();

    expect(await File(testPath).readAsString(), before);
  });

  test('U-V7: no Presentation contract → the literal-only composition, '
      'still scaffolded and deterministic', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back'",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('no Presentation layer contract declared'));
    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(subject, contains("Text('Welcome back')"));
    expect(subject, contains('Widget subject_a_001() => A001View();'));
  });

  test(
    'U-V8: determinism — identical inputs render byte-identical views',
    () async {
      Future<String> renderOnce() async {
        final fixture = await TddFixture.create();
        try {
          await Directory('${fixture.root.path}/lib').create(recursive: true);
          await fixture.registerBehavior(
            id: 'A-001',
            description:
                "the login page shows 'Welcome back' with a sign in button",
          );
          await File(
            fixture.subjectPathOf('A-001'),
          ).writeAsString(genStyleWidgetStub('A-001'));
          await seedPresentationContract(fixture);
          final runner = CliRunner(exitOnCompletion: false);
          await runner.runCapturing([
            'tdd',
            'view',
            'A-001',
            '--project',
            fixture.root.path,
          ]);
          final rendered = await File(
            fixture.subjectPathOf('A-001'),
          ).readAsString();
          return rendered;
        } finally {
          fixture.dispose();
          exitCode = 0;
        }
      }

      final first = await renderOnce();
      final second = await renderOnce();
      expect(first, equals(second), reason: 'the view must be deterministic');
    },
  );

  test('U-V9: only the matched stub declaration is replaced; surrounding '
      'source content is preserved', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: 'the login page renders',
    );
    const preamble =
        "// hand note: keep this helper below\n"
        "String loginTitle() => 'login';\n";
    await File(fx.subjectPathOf('A-001')).writeAsString('''
library;

$preamble
${genStyleWidgetStub('A-001').split('\n').skip(1).join('\n')}
''');

    await runView();

    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(subject, contains('keep this helper below'));
    expect(subject, contains('String loginTitle()'));
    expect(subject, contains('Widget subject_a_001() => A001View();'));
  });
}
