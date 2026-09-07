@Tags(['slow'])
// Bug #1258 — the SKIN lane dead-ends at `make`: `zfa tdd gen --kind widget`
// emits a widget test whose scenario assertions are placeholder finders
// carrying the `zfa:tdd: scaffolded` marker, and `zfa tdd make` REFUSES to
// certify green on exactly that test — but no zfa command performs the
// replacement the refusal demands, and hand-editing a registry-owned test
// is an out-of-contract mutation. The fix: `zfa tdd make --author
// --finders-file <path>` — the sanctioned skin-authoring transition that
// (a) replaces the scaffolded placeholder block with author-supplied
// concrete finders and clears the marker, (b) re-certifies red-before-green
// honestly (only an assertion-classified red certifies — the born-green
// vacuity refuses and restores), (c) writes the hand-delta receipt into
// the feature's provenance ledger, and (d) resumes the normal make flow so
// the driver no longer stops at `<id>:make`.
//
// Drives the public CLI surface (`zfa tdd make`) against a TddFixture, the
// same harness as make_command_test.dart / make_command_widget_939_test.dart.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_authoring.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd make`, pinning the project root.
List<String> makeArgs(
  TddFixture fx, {
  String? id,
  String? zfaBin,
  String? feature,
  bool author = false,
  String? findersFile,
}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (feature != null) args.addAll(['--feature', feature]);
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  if (author) args.add('--author');
  if (findersFile != null) args.addAll(['--finders-file', findersFile]);
  if (id != null) args.add(id);
  return args;
}

const _behaviorId = 'W-1258';
const _description = 'the system initiates Apple sign-in';

/// The subject symbol TddFixture derives from the id (`W-1258` →
/// `w_1258`), matching [TddFixture.subjectPathOf]/[TddFixture.subjectReturning].
const _subjectSymbol = 'w_1258';

/// A SCAFFOLDED widget test in the exact shape `BehaviorTestWriter
/// ._renderWidgetTest` emits when no finder is derivable from the
/// scenario description (issue #912 defect 3, the #1258 dead-end): the
/// marker comment block followed by the mounted-view placeholder.
///
/// The placeholder line does not compile against the pure-Dart fixture —
/// it never has to run: the certified-red precondition is seeded, and the
/// authoring transition replaces the whole block BEFORE any run.
String scaffoldedWidgetTest(String description) =>
    '''
import '../lib/${_subjectSymbol}_subject.dart';
import 'package:test/test.dart';

void main() {
  test("$description", () {
      $widgetScaffoldComment
      expect(find.byWidget(view), findsOneWidget);
  });
}
''';

void main() {
  late TddFixture fx;

  /// Seed the full #1258 dead-end state: a widget-kind row, the
  /// scaffolded test + inert stub subject in the registry, and the
  /// bootstrap red evidence (the sequence-variant lane certified it the
  /// same way before the placeholder-only shape started refusing).
  Future<void> seedScaffoldedDeadEnd() async {
    await fx.seedTestList([
      (
        id: _behaviorId,
        description: _description,
        traces: 'FR-1258',
        state: 'PENDING',
        kind: 'widget',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: _behaviorId,
      description: _description,
      // The gen-shaped inert stub SubjectWriter emits (bug #830): the
      // scenario is unsatisfied — the authored red must fail against it.
      subjectContent:
          '''
// GENERATED STUB — `zfa tdd gen $_behaviorId` (spec 044-test-tdd-generation).
library;

/// View-builder subject for behavior $_behaviorId.
int ${_subjectSymbol}_value() => 0;
''',
      testContent: scaffoldedWidgetTest(_description),
    );
  }

  /// Author-supplied concrete finders that derive from the scenario and
  /// fail against the inert stub (the honest authored red), then pass
  /// once the view lane implements the subject.
  Future<String> writeAuthorFinders(String statement) async {
    final path = p.join(fx.root.path, 'author-finders.dart.snippet');
    await File(path).writeAsString('$statement\n');
    return path;
  }

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('SkinAuthoring (pure patch contract)', () {
    final scaffoldedBody = scaffoldedWidgetTest(_description);

    test('replaces the scaffolded block with the author finders and '
        'clears the marker', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedBody,
        authorFinders:
            "expect(find.text('Sign in with Apple'), findsOneWidget);",
      );
      expect(
        contentIsScaffolded(patched),
        isFalse,
        reason: 'the marker must be cleared',
      );
      expect(
        patched,
        isNot(contains('expect(find.byWidget(view), findsOneWidget);')),
        reason: 'the vacuous placeholder must be gone',
      );
      expect(
        patched,
        contains("expect(find.text('Sign in with Apple'), findsOneWidget);"),
      );
      // The rest of the test scaffolding survives the patch.
      expect(patched, contains("test(\"$_description\""));
      expect(patched, contains("import 'package:test/test.dart';"));
    });

    test('multi-line author blocks keep their line breaks', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedBody,
        authorFinders:
            'final button = find.byType(Scaffold);\n'
            'expect(button, findsOneWidget);',
      );
      expect(patched, contains('final button = find.byType(Scaffold);'));
      expect(patched, contains('expect(button, findsOneWidget);'));
    });

    test('refuses author finders that carry the scaffold marker', () {
      expect(
        () => SkinAuthoring.patchedContent(
          testContent: scaffoldedBody,
          authorFinders: '// $scaffoldedMarker still scaffolded\nexpect(1, 1);',
        ),
        throwsA(isA<SkinAuthoringException>()),
      );
    });

    test('refuses author finders with no concrete assertion', () {
      expect(
        () => SkinAuthoring.validateAuthorFinders('// just a comment\n'),
        throwsA(isA<SkinAuthoringException>()),
      );
      expect(
        () => SkinAuthoring.validateAuthorFinders(''),
        throwsA(isA<SkinAuthoringException>()),
      );
    });

    test('refuses patching content that is not scaffolded', () {
      expect(
        () => SkinAuthoring.patchedContent(
          testContent: 'void main() {}',
          authorFinders: 'expect(1, 1);',
        ),
        throwsA(isA<SkinAuthoringException>()),
      );
    });
  });

  group('SuiteGuard.parse — compact-reporter padding tolerance (#1258 '
      'enabling fix)', () {
    const guard = SuiteGuard();

    test('a real red transcript with trailing terminal padding parses its '
        'failing tests', () {
      // The exact shape `--reporter compact` emits when the child pads
      // progress lines to the terminal width: the [E] marker is NOT at
      // line end, and no `Failing tests:` block is printed.
      const padded =
          '00:00 +0: loading test/w_test.dart'
          '                                                              \n'
          '00:00 +0 -1: test/w_test.dart: the scenario [E]'
          '                                        \n'
          '  Expected: <42>\n'
          '    Actual: <0>\n'
          '00:00 +0 -1: Some tests failed.'
          '                                                             \n';
      final snap = guard.parse(
        command: 'dart test',
        exitCode: 1,
        output: padded,
        capturedAt: '2026-09-07T00:00:00.000Z',
      );
      expect(snap.parseable, isTrue, reason: snap.toString());
      expect(snap.failedTests, contains('test/w_test.dart: the scenario'));
    });

    test('a padded GREEN transcript still parses clean (no fabricated '
        'failures)', () {
      const padded =
          '00:00 +1: test/w_test.dart: the scenario'
          '                                                            \n'
          '00:00 +1: All tests passed!'
          '                                                             \n';
      final snap = guard.parse(
        command: 'dart test',
        exitCode: 0,
        output: padded,
        capturedAt: '2026-09-07T00:00:00.000Z',
      );
      expect(snap.parseable, isTrue);
      expect(snap.failedTests, isEmpty);
    });

    test('CR-redrawn compact transcripts parse (bare \\r between frames)', () {
      const redrawn =
          '00:00 +0: loading test/w_test.dart\r'
          '00:00 +0 -1: test/w_test.dart: the scenario [E]\r'
          '00:00 +0 -1: Some tests failed.\n';
      final snap = guard.parse(
        command: 'dart test',
        exitCode: 1,
        output: redrawn,
        capturedAt: '2026-09-07T00:00:00.000Z',
      );
      expect(snap.parseable, isTrue);
      expect(snap.failedTests, contains('test/w_test.dart: the scenario'));
    });
  });

  group('make --author — the sanctioned skin-authoring transition', () {
    test('U1: replaces the scaffolded finders, re-certifies the authored '
        'red, writes the hand-delta receipt, and certifies green through '
        'the view lane — exit 0', () async {
      await seedScaffoldedDeadEnd();
      final findersFile = await writeAuthorFinders(
        'expect(${_subjectSymbol}_value(), equals(42));',
      );
      // The view lane's generation step implements the subject (the
      // deterministic minimal view the real `zfa tdd view` renders).
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd view': fx.overwriteSubjectCommands(
            _behaviorId,
            TddFixture.subjectReturning(_behaviorId, 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(
          fx,
          id: _behaviorId,
          zfaBin: zfaBin,
          author: true,
          findersFile: findersFile,
        ),
      );

      // (d) the driver resumes: the make certifies green, exit 0.
      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'make: behavior=$_behaviorId outcome=green '
          'feature=${fx.featureName}',
        ),
        reason: out,
      );
      // The pipeline ran the view-builder lane (generation happened).
      final fakeLog = await fx.readFakeZfaLog();
      expect(
        fakeLog.any((l) => l.contains('tdd view')),
        isTrue,
        reason: 'the view lane must run after authoring: $fakeLog',
      );

      // (a) the test is concrete: marker cleared, placeholder gone,
      // author finders present.
      final testContent = await File(fx.testPathOf(_behaviorId)).readAsString();
      expect(contentIsScaffolded(testContent), isFalse);
      expect(testContent, isNot(contains('find.byWidget(view)')));
      expect(
        testContent,
        contains('expect(${_subjectSymbol}_value(), equals(42));'),
      );

      // (b) red-before-green was re-certified honestly: the cycle-log
      // carries the AUTHORED red (captured from a real failing run)
      // before the green entry.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: $_behaviorId (red)'));
      expect(cycleLog, contains('## Cycle: $_behaviorId (green)'));
      final redIdx = cycleLog.indexOf('## Cycle: $_behaviorId (red)');
      final greenIdx = cycleLog.indexOf('## Cycle: $_behaviorId (green)');
      expect(redIdx, lessThan(greenIdx), reason: 'red before green');
      expect(
        cycleLog,
        contains('- command: `'),
        reason: 'the authored red carries a real runner command',
      );

      // (c) the hand delta is registered in the provenance ledger.
      final ledgerFile = File(
        p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
      );
      expect(ledgerFile.existsSync(), isTrue, reason: 'ledger must exist');
      final ledger = ledgerFile.readAsStringSync();
      expect(ledger, contains('"recordedBy": "zfa tdd make --author"'));
      expect(ledger, contains('issue #1258'));
      expect(ledger, contains(_behaviorId));
      expect(
        ledger,
        contains('w_1258_test.dart'),
        reason: 'the receipt binds the authored test file',
      );
    });

    test('U2: without --author the refusal stands and the test tree is '
        'untouched (backward compatibility)', () async {
      await seedScaffoldedDeadEnd();
      final before = await File(fx.testPathOf(_behaviorId)).readAsString();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: _behaviorId, zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0));
      expect(out, contains('SCAFFOLDED'));
      expect(out, contains('outcome=scaffolded'));
      // No generation ran, nothing changed.
      expect(await fx.readFakeZfaLog(), isEmpty);
      expect(
        await File(fx.testPathOf(_behaviorId)).readAsString(),
        equals(before),
      );
      expect(
        File(
          p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
        ).existsSync(),
        isFalse,
      );
    });

    test(
      'U3: the born-green vacuity refuses and RESTORES the scaffolded '
      'bytes — finders the inert stub already satisfies prove nothing',
      () async {
        await seedScaffoldedDeadEnd();
        final findersFile = await writeAuthorFinders('expect(1, equals(1));');
        final before = await File(fx.testPathOf(_behaviorId)).readAsString();
        final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(
            fx,
            id: _behaviorId,
            zfaBin: zfaBin,
            author: true,
            findersFile: findersFile,
          ),
        );

        expect(exitCode, isNot(0));
        expect(out, contains('born-green'), reason: out);
        // The scaffolded bytes were restored byte-identical.
        expect(
          await File(fx.testPathOf(_behaviorId)).readAsString(),
          equals(before),
        );
        // No evidence, no receipt, no generation.
        expect(
          File(
            p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
          ).existsSync(),
          isFalse,
        );
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, isNot(contains('## Cycle: $_behaviorId (green)')));
        expect(await fx.readFakeZfaLog(), isEmpty);
      },
    );

    test('U4: --author on a non-scaffolded test is a misfire — refused '
        'before any state change', () async {
      await seedScaffoldedDeadEnd();
      // Replace the test with a plain (non-scaffolded) red test.
      await File(
        fx.testPathOf(_behaviorId),
      ).writeAsString(TddFixture.redTest(_description));
      final findersFile = await writeAuthorFinders(
        'expect(${_subjectSymbol}_value(), equals(42));',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(
          fx,
          id: _behaviorId,
          zfaBin: zfaBin,
          author: true,
          findersFile: findersFile,
        ),
      );

      expect(exitCode, isNot(0));
      expect(out, contains('--author'), reason: out);
      expect(out, contains('outcome=runner-error'));
      expect(await fx.readFakeZfaLog(), isEmpty);
    });

    test('U5: --author without --finders-file is a usage refusal', () async {
      await seedScaffoldedDeadEnd();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: _behaviorId, zfaBin: zfaBin, author: true),
      );

      expect(exitCode, isNot(0));
      expect(out, contains('--finders-file'), reason: out);
      expect(await fx.readFakeZfaLog(), isEmpty);
    });

    test('U6: author finders that do not compile refuse honestly and '
        'restore the scaffolded bytes (never a fabricated red)', () async {
      await seedScaffoldedDeadEnd();
      final findersFile = await writeAuthorFinders(
        'expect(undefinedSymbolFromNowhere(), equals(42));',
      );
      final before = await File(fx.testPathOf(_behaviorId)).readAsString();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(
          fx,
          id: _behaviorId,
          zfaBin: zfaBin,
          author: true,
          findersFile: findersFile,
        ),
      );

      expect(exitCode, isNot(0));
      expect(out, contains('classification: compile-error'), reason: out);
      expect(
        await File(fx.testPathOf(_behaviorId)).readAsString(),
        equals(before),
      );
      expect(
        File(
          p.join(fx.featureDir, 'tdd', 'provenance-ledger.json'),
        ).existsSync(),
        isFalse,
      );
    });
  });
}
