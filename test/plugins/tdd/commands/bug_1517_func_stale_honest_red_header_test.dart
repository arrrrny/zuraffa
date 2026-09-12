// Bug #1517: `zfa tdd func` fills a declared stub's body (e.g. `return
// true;` for a bool) but preserves the gen-time stub header and doc
// comment verbatim. The surviving text still claims "honest red" /
// "Throws [UnimplementedError]" — now false: the paired test compiles
// and goes green on the dummy body alone (caught by automated review of
// #1501, fixture 004-login-ui U2; the stale text had to be hand-corrected
// in commit 9960d905).
//
// RED: after func installs a dummy body, the header/doc comment must
// describe the scaffolded-dummy state (no stale honest-red /
// UnimplementedError claims) while the contract traces (behavior_id,
// source_criterion, description, declared-signature fence, declared
// parameters) are preserved verbatim.
//
// GREEN guard: a still-red scaffold (a non-renderable declared return
// that keeps UnimplementedError) must keep its honest-red claims — they
// remain true there.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

import '../helpers/tdd_fixture.dart';

/// The gen-shaped CONTRACT-DERIVED unit stub SubjectWriter emits for a
/// declared `isSubmittable(String email, String password) -> bool`
/// behavior (issue #1259) — header and doc comment carry honest-red
/// claims that are gen-time-accurate and fill-time-stale.
String contractUnitBoolStub(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  const signature = 'isSubmittable(String email, String password) -> bool';
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// behavior_id: $id
// source_criterion: FR-002, LoginValidation.validate
// description: The system MUST require the password to be at least 8 characters long.
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contract:
//
//     $signature
//
// The declared request and result types are preserved above. A
// non-renderable declared type (an entity that does not exist yet)
// renders as `Object?` so the stub compiles cleanly (FR-011); replace
// it with the declared type when implementing. This is a MINIMAL
// COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
// fails on first execution (honest red). Replace this stub body with
// the real implementation of the declared contract to make the test
// pass.
// Declared parameters: email: String, password: String
//
// The subject name is derived from the behavior id and is deliberately
// snake_cased — the generator KNOWS the name it emits, so the lint its
// shape provably trips is suppressed here rather than renaming the
// contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior $id — declared contract:
/// `$signature`.
///
/// Throws [UnimplementedError] until the real implementation lands.
bool subject_$symbol(String email, String password) => throw UnimplementedError('subject_$symbol not implemented: $signature');
''';
}

/// The gen-shaped contract-unit stub for a NON-renderable declared
/// return (`validate(Credentials) -> LoginVerdict`): the declared types
/// degrade to `Object?` (FR-011) and func's scaffold stays red.
String contractUnitEntityReturnStub(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  const signature = 'validate(Credentials) -> LoginVerdict';
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// behavior_id: $id
// source_criterion: FR-002, LoginValidation.validate
// description: The system MUST return the login verdict.
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contract:
//
//     $signature
//
// The declared request and result types are preserved above. A
// non-renderable declared type (an entity that does not exist yet)
// renders as `Object?` so the stub compiles cleanly (FR-011); replace
// it with the declared type when implementing. This is a MINIMAL
// COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
// fails on first execution (honest red). Replace this stub body with
// the real implementation of the declared contract to make the test
// pass.
// Declared parameters: credentials: Credentials (non-renderable declared types render as Object? until implemented)
//
// The subject name is derived from the behavior id and is deliberately
// snake_cased — the generator KNOWS the name it emits, so the lint its
// shape provably trips is suppressed here rather than renaming the
// contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior $id — declared contract:
/// `$signature`.
///
/// Throws [UnimplementedError] until the real implementation lands.
Object? subject_$symbol(Object? credentials) => throw UnimplementedError('subject_$symbol not implemented: $signature');
''';
}

/// The gen-shaped LEGACY no-arg unit stub SubjectWriter emits for an
/// undeclared behavior (issue #657) — the honest-red header + doc
/// comment variant of the same bug.
String legacyUnitStub(String id, String description) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation).
//
// behavior_id: $id
// source_criterion: FR-007
// description: $description
//
// This is a MINIMAL COMPILABLE STUB. It compiles cleanly (FR-011) but
// does NOT satisfy the behavior described above — the paired test will
// fail on first execution with an assertion-level failure (honest red).
// Replace this stub body with real implementation to make the test pass.
//
// The subject name is derived from the behavior id (`subject_$symbol`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
int subject_$symbol() => throw UnimplementedError('subject_$symbol not implemented');
''';
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

  Future<String> runFunc(String id) {
    final runner = CliRunner(exitOnCompletion: false);
    final args = <String>['tdd', 'func', id, '--project', fx.root.path];
    return runner.runCapturing(args);
  }

  test('U-1517-1: after func fills a declared bool stub with `return true;` '
      'the header/doc comment describe the scaffolded-dummy state — no '
      'stale honest-red / UnimplementedError claims', () async {
    const description =
        'The system MUST require the password to be at least 8 characters '
        'long.';
    await fx.seedTestList([
      (
        id: 'U2',
        description: description,
        traces: 'LoginValidation.isSubmittable',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'U2',
      description: description,
      testContent: "import 'package:test/test.dart';\nvoid main() {}\n",
      subjectContent: contractUnitBoolStub('U2'),
    );
    // The spec declares the Layer Contract the behavior traces to: a
    // bool return over two scalar params — the dummy-body case.
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString(
      '### Layer Contracts\n\n**Function**:\n'
      '- `LoginValidation`: `isSubmittable(String email, String password) '
      '-> bool`\n',
    );

    final out = await runFunc('U2');

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains(
        'func: behavior=U2 outcome=scaffolded feature=${fx.featureName}',
      ),
    );
    final subject = await File(fx.subjectPathOf('U2')).readAsString();
    // The dummy body was installed (the fill step itself — unchanged).
    expect(subject, contains('bool subject_u2(String email, String password)'));
    expect(subject, contains('return true;'));
    // The stale gen-time claims are gone ...
    expect(subject, isNot(contains('honest red')), reason: subject);
    expect(subject, isNot(contains('UnimplementedError')), reason: subject);
    expect(subject, isNot(contains('MINIMAL COMPILABLE')), reason: subject);
    // ... replaced by a claim that matches the actual state: a
    // scaffolded dummy, not an honest red.
    expect(subject.toLowerCase(), contains('dummy'), reason: subject);
    // Contract traces are preserved verbatim in the header.
    expect(subject, contains('behavior_id: U2'), reason: subject);
    expect(
      subject,
      contains('source_criterion: FR-002, LoginValidation.validate'),
      reason: subject,
    );
    expect(subject, contains('// description: $description'), reason: subject);
    expect(
      subject,
      contains('//     isSubmittable(String email, String password) -> bool'),
      reason: subject,
    );
    expect(
      subject,
      contains('Declared parameters: email: String, password: String'),
      reason: subject,
    );
    // The mid-line splice vacates the tail of the claim's first line; the
    // separator's space must not be left behind — `dart format
    // --set-exit-if-changed` (CI) rewrites exactly such a line.
    for (final line in subject.split('\n')) {
      expect(line, line.trimRight(), reason: 'trailing whitespace: >$line<');
    }
  });

  test(
    'U-1517-2: after func fills a legacy no-arg unit stub the honest-red '
    'header and doc comment are reconciled to the scaffolded-dummy state',
    () async {
      const description = 'return true when the task is fully populated';
      await fx.registerBehavior(id: 'B-1517', description: description);
      await File(
        fx.subjectPathOf('B-1517'),
      ).writeAsString(legacyUnitStub('B-1517', description));

      final out = await runFunc('B-1517');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('B-1517')).readAsString();
      expect(subject, contains('bool subject_b_1517()'));
      expect(subject, contains('return true;'));
      expect(subject, isNot(contains('honest red')), reason: subject);
      expect(subject, isNot(contains('UnimplementedError')), reason: subject);
      expect(subject, isNot(contains('MINIMAL COMPILABLE')), reason: subject);
      expect(subject.toLowerCase(), contains('dummy'), reason: subject);
      // The header's own traces survive the rewrite.
      expect(subject, contains('behavior_id: B-1517'), reason: subject);
      expect(
        subject,
        contains('// description: $description'),
        reason: subject,
      );
    },
  );

  test('U-1517-3: a still-red scaffold (non-renderable declared return) '
      'keeps its honest-red claims — they remain true there', () async {
    const description = 'The system MUST return the login verdict.';
    await fx.seedTestList([
      (
        id: 'U3',
        description: description,
        traces: 'LoginValidation.validate',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: 'U3',
      description: description,
      testContent: "import 'package:test/test.dart';\nvoid main() {}\n",
      subjectContent: contractUnitEntityReturnStub('U3'),
    );
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString(
      '### Layer Contracts\n\n**Function**:\n'
      '- `LoginValidation`: `validate(Credentials) -> LoginVerdict`\n',
    );

    final out = await runFunc('U3');

    expect(exitCode, 0, reason: 'out: $out');
    final subject = await File(fx.subjectPathOf('U3')).readAsString();
    // The scaffold stays red — implement per declared signature.
    expect(
      subject,
      contains("throw UnimplementedError('implement per declared signature"),
      reason: subject,
    );
    // The honest-red claims remain ACCURATE for this state — func must
    // not strip them.
    expect(subject, contains('honest red'), reason: subject);
    expect(
      subject,
      contains('Throws [UnimplementedError] until the real implementation'),
      reason: subject,
    );
  });

  test(
    'U-1517-4: the acceptance-scenario claim variant is reconciled too '
    '(the fixture is rendered by SubjectWriter, so template drift shows)',
    () async {
      const id = 'A1';
      const description =
          'The system MUST let an actor complete the checkout scenario.';
      await fx.seedTestList([
        (
          id: id,
          description: description,
          traces: 'Checkout.complete',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      final acceptanceStub = const SubjectWriter().render(
        Behavior(
          id: id,
          feature: fx.featureName,
          kind: BehaviorKind.acceptance,
          description: description,
          sourceCriterion: 'FR-004',
          target: 'subject_a1',
        ),
      );
      // The fixture really carries the acceptance variant, not the unit one.
      expect(
        acceptanceStub,
        contains('MINIMAL COMPILABLE acceptance-scenario stub'),
      );
      await fx.seedCertifiedRed(
        id: id,
        description: description,
        testContent: "import 'package:test/test.dart';\nvoid main() {}\n",
        subjectContent: acceptanceStub,
      );

      final out = await runFunc(id);

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf(id)).readAsString();
      expect(subject, isNot(contains('honest red')), reason: subject);
      expect(subject, isNot(contains('UnimplementedError')), reason: subject);
      expect(subject, isNot(contains('MINIMAL COMPILABLE')), reason: subject);
      expect(subject.toLowerCase(), contains('dummy'), reason: subject);
      // Traces survive the rewrite.
      expect(subject, contains('behavior_id: $id'), reason: subject);
      expect(
        subject,
        contains('// description: $description'),
        reason: subject,
      );
    },
  );

  test('U-1517-5: a hand-authored stub keeps its own note (only the '
      'generated header/doc blocks are reconciled) and still gets the '
      'state statement', () async {
    const id = 'H1';
    const description = 'return true when the hand-authored stub is populated';
    await fx.registerBehavior(id: id, description: description);
    const userNote =
        '// TODO: still throws UnimplementedError on the null path.';
    await File(fx.subjectPathOf(id)).writeAsString('''
$userNote
library;

int subject_h1() => throw UnimplementedError('subject_h1 not implemented');
''');

    final out = await runFunc(id);

    expect(exitCode, 0, reason: 'out: $out');
    final subject = await File(fx.subjectPathOf(id)).readAsString();
    expect(subject, contains('return true;'), reason: subject);
    // The hand-authored line is NOT a generated claim — it must survive.
    expect(subject, contains(userNote), reason: subject);
    // There was no generated header to rewrite, so the fallback note
    // states the scaffolded-dummy state.
    expect(subject, contains('Scaffolded dummy'), reason: subject);
  });
}
