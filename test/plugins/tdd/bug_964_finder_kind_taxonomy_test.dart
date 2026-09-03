// Issue #964 (TDD-137) — the finder-kind taxonomy for the widget lane.
//
// The pre-#964 pipeline flattened every quoted scenario literal into a
// `find.text` presence assertion and discarded the scenario verb, so a
// scenario asserting "the app navigates to the route `deal_list`" was
// certified green by a static `Column` of `Text` widgets — the certified
// lie. These tests pin the taxonomy end to end:
//
//   1. classification: verb → assertion class, literal → kind;
//   2. emission: the generated widget test's assertions are verb-matched
//      (route outcome through a recording NavigatorObserver, absence
//      through findsNothing, sequence marked scaffolded);
//   3. view composition: route literals render an affordance, never the
//      route name as on-screen text; absence literals render nothing;
//   4. verify-red kind gate: a red whose finder kinds do not match the
//      scenario verbs is refused (kind-mismatch), never certified.
//
// The runner is scripted via spy profiles (no real `dart test`
// subprocess), so the whole file stays in the fast tier.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/finder_taxonomy.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  /// A failing single-test transcript with an assertion signature
  /// (classification=assertion), emitted by the spy runner.
  const failingTranscript = '''
00:00 +0 -1: test/a4_test.dart: A4 nav [E]
00:00 -1: Expected: contains 'deal_list'
  Actual: Which: <[]>

Some tests failed.
''';

  group('FinderTaxonomy.analyze: verb → assertion class', () {
    test('presence verbs keep the literal a find.text assertion', () {
      final analysis = FinderTaxonomy.analyze(
        "shows the 'Add to cart' action on the product view",
      );
      expect(analysis.sequence, isFalse);
      expect(analysis.needsRouteObserver, isFalse);
      expect(analysis.assertions, hasLength(1));
      expect(
        analysis.assertions.single.assertionClass,
        ScenarioAssertionClass.presence,
      );
      expect(analysis.assertions.single.kind, LiteralKind.text);
      expect(analysis.assertions.single.literal, 'Add to cart');
    });

    test('the 004-login-ui A4 scenario is a ROUTE OUTCOME, not presence', () {
      // The exact defect class of issue #964: this scenario was certified
      // green by `expect(find.text('deal_list'), findsOneWidget)` while
      // nothing navigated.
      final analysis = FinderTaxonomy.analyze(
        'the app navigates to the route "deal_list"',
      );
      expect(analysis.assertions, hasLength(1));
      expect(
        analysis.assertions.single.assertionClass,
        ScenarioAssertionClass.routeOutcome,
      );
      expect(analysis.assertions.single.kind, LiteralKind.route);
      expect(analysis.assertions.single.literal, 'deal_list');
      expect(analysis.needsRouteObserver, isTrue);
    });

    test(
      'passive navigation conjugation is classified too (bug #936 grammar)',
      () {
        final analysis = FinderTaxonomy.analyze(
          "the user is navigated to 'order_confirm' after sign-in",
        );
        expect(
          analysis.assertions.single.assertionClass,
          ScenarioAssertionClass.routeOutcome,
        );
      },
    );

    test('the nearest preceding verb wins in a mixed scenario', () {
      final analysis = FinderTaxonomy.analyze(
        "navigates to the route 'deal_list' and shows 'Welcome'",
      );
      expect(analysis.assertions, hasLength(2));
      expect(analysis.assertions[0].literal, 'deal_list');
      expect(
        analysis.assertions[0].assertionClass,
        ScenarioAssertionClass.routeOutcome,
      );
      expect(analysis.assertions[1].literal, 'Welcome');
      expect(
        analysis.assertions[1].assertionClass,
        ScenarioAssertionClass.presence,
      );
    });

    test('a literal after a navigation clause stays presence', () {
      // "navigates" appears AFTER the literal — the literal's nearest
      // PRECEDING verb is "shows".
      final analysis = FinderTaxonomy.analyze(
        "shows 'Order sent' while the app navigates to the next screen",
      );
      expect(analysis.assertions.single.literal, 'Order sent');
      expect(
        analysis.assertions.single.assertionClass,
        ScenarioAssertionClass.presence,
      );
    });

    test('absence verbs derive a findsNothing assertion', () {
      final analysis = FinderTaxonomy.analyze(
        'the error banner hides "An error occurred" after a retry',
      );
      expect(
        analysis.assertions.single.assertionClass,
        ScenarioAssertionClass.absence,
      );
    });

    test('the explicit absent: prefix derives absence regardless of prose', () {
      final analysis = FinderTaxonomy.analyze(
        'renders "absent: An error occurred" on initial load',
      );
      expect(
        analysis.assertions.single.assertionClass,
        ScenarioAssertionClass.absence,
      );
      expect(analysis.assertions.single.literal, 'An error occurred');
    });

    test('enabled-state verbs carry their polarity', () {
      final disabled = FinderTaxonomy.analyze('disables the "Sign in" button');
      expect(
        disabled.assertions.single.assertionClass,
        ScenarioAssertionClass.enabledState,
      );
      expect(disabled.assertions.single.disabled, isTrue);

      final enabled = FinderTaxonomy.analyze('enables the "Sign in" button');
      expect(
        enabled.assertions.single.assertionClass,
        ScenarioAssertionClass.enabledState,
      );
      expect(enabled.assertions.single.disabled, isFalse);
    });

    test('an in-flight clause marks the scenario as a sequence', () {
      final analysis = FinderTaxonomy.analyze(
        'while sign-in is in flight, shows "Signing in" and disables the '
        '"Sign in" button',
      );
      expect(analysis.sequence, isTrue);
      expect(
        analysis.requiredClasses,
        containsAll(<ScenarioAssertionClass>[
          ScenarioAssertionClass.presence,
          ScenarioAssertionClass.enabledState,
        ]),
      );
    });

    test('descriptions without quoted literals derive no assertions', () {
      final analysis = FinderTaxonomy.analyze('renders the dashboard shell');
      expect(analysis.assertions, isEmpty);
      expect(FinderTaxonomy.headerLine(analysis), isEmpty);
    });
  });

  group('FinderTaxonomy: header + kind gate', () {
    test('headerLine traces every assertion class machine-readably', () {
      final analysis = FinderTaxonomy.analyze(
        'while sign-in is in flight, shows "Signing in" and disables the '
        '"Sign in" button',
      );
      final header = FinderTaxonomy.headerLine(analysis);
      expect(header, startsWith('// scenario-assertions:'));
      expect(header, contains('sequence'));
      expect(header, contains('presence("Signing in")'));
      expect(header, contains('enabled-state("Sign in")(disabled)'));
    });

    test(
      'unsatisfiedClasses: a find.text-only navigation test is a mismatch',
      () {
        // The exact old-style A4 test of issue #964.
        const oldStyleTest = '''
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a4', (tester) async {
    expect(find.text('deal_list'), findsOneWidget);
  });
}
''';
        final analysis = FinderTaxonomy.analyze(
          'the app navigates to the route "deal_list"',
        );
        expect(
          FinderTaxonomy.unsatisfiedClasses(analysis, oldStyleTest),
          equals(<ScenarioAssertionClass>{ScenarioAssertionClass.routeOutcome}),
        );
      },
    );

    test('unsatisfiedClasses: a route-outcome test satisfies its scenario', () {
      const newStyleTest = '''
void main() {
  testWidgets('a4', (tester) async {
    expect(observer.pushedNames, contains('deal_list'),
        reason: 'navigation');
  });
}
''';
      final analysis = FinderTaxonomy.analyze(
        'the app navigates to the route "deal_list"',
      );
      expect(
        FinderTaxonomy.unsatisfiedClasses(analysis, newStyleTest),
        isEmpty,
      );
    });

    test('unsatisfiedClasses: presence scenarios satisfy find.text tests', () {
      const presenceTest = '''
void main() {
  testWidgets('a1', (tester) async {
    expect(find.text('Add to cart'), findsOneWidget);
  });
}
''';
      final analysis = FinderTaxonomy.analyze(
        "shows the 'Add to cart' action on the product view",
      );
      expect(
        FinderTaxonomy.unsatisfiedClasses(analysis, presenceTest),
        isEmpty,
      );
    });
  });

  group('BehaviorTestWriter: verb-matched emission', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('bug964_writer_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    Future<String> renderWidget(String description) async {
      final testPath = p.join(tmpDir.path, 'w_1_test.dart');
      await BehaviorTestWriter().write(
        behavior: Behavior(
          id: 'A4',
          feature: '964-finder-kind-taxonomy',
          kind: BehaviorKind.widget,
          description: description,
          sourceCriterion: 'AC-4',
          target: 'subject_a4',
        ),
        testPath: testPath,
        subjectPath: p.join(tmpDir.path, 'w_1_subject.dart'),
      );
      return File(testPath).readAsString();
    }

    test('an A4-class scenario emits a route-outcome assertion, NEVER '
        'find.text of the route name (issue #964 acceptance 1)', () async {
      final content = await renderWidget(
        'the app navigates to the route "deal_list"',
      );
      expect(content, contains('final observer = _RouteRecorder();'));
      expect(
        content,
        contains('navigatorObservers: <NavigatorObserver>[observer],'),
      );
      expect(
        content,
        contains("expect(observer.pushedNames, contains('deal_list'),"),
      );
      expect(
        content,
        isNot(contains("find.text('deal_list')")),
        reason:
            'asserting the route name as on-screen text is the certified '
            'lie of issue #964',
      );
      expect(
        content,
        isNot(contains('expect(find.byWidget(view), findsOneWidget);')),
        reason:
            'route-outcome tests carry no mounted-view smoke assertion: '
            'after the route is pushed the home route goes offstage and '
            'find.byWidget(view) would fail the green path (found by the '
            'flutter runtime probe)',
      );
      expect(
        content,
        contains('// scenario-assertions: route-outcome("deal_list")'),
      );
      // Honest red is preserved: the stub's UnimplementedError is still
      // captured as an assertion before the pump.
      expect(
        content,
        contains('expect(built, isNot(isA<UnimplementedError>()));'),
      );
      expect(content, isNot(contains(scaffoldedMarker)));
      // The recorder class lands in the file and extends NavigatorObserver.
      expect(
        content,
        contains('class _RouteRecorder extends NavigatorObserver'),
      );
    });

    test(
      'an absence scenario emits findsNothing (issue #964 acceptance 2)',
      () async {
        final content = await renderWidget(
          'the error banner hides "An error occurred" after a retry',
        );
        expect(
          content,
          contains("expect(find.text('An error occurred'), findsNothing);"),
        );
        expect(
          content,
          contains('// scenario-assertions: absence("An error occurred")'),
        );
        expect(content, isNot(contains(scaffoldedMarker)));
      },
    );

    test('an enabled-state scenario asserts onPressed null-ness through an '
        'assertion, never a finder throw', () async {
      final content = await renderWidget(
        'after the failed sign-in the "Sign in" button is disabled',
      );
      expect(
        content,
        contains("find.widgetWithText(ElevatedButton, 'Sign in')"),
      );
      expect(content, contains('.onPressed,'));
      expect(content, contains('isNull'));
      expect(
        content,
        contains('// scenario-assertions: enabled-state("Sign in")(disabled)'),
      );
    });

    test('a sequence scenario is marked SCAFFOLDED, never flattened to '
        'presence (issue #964: presence cannot see sequences)', () async {
      final content = await renderWidget(
        'while sign-in is in flight, shows "Signing in" and disables the '
        '"Sign in" button',
      );
      expect(content, contains(scaffoldedMarker));
      expect(content, contains('SEQUENCE scenario (issue #964)'));
      // The derivable sub-assertions are still emitted — honest parts of
      // the sequence — but the marker keeps green certification off.
      expect(
        content,
        contains("expect(find.text('Signing in'), findsOneWidget);"),
      );
      expect(content, contains('sequence'));
    });

    test(
      'a presence scenario is byte-compatible with the #912 shape',
      () async {
        final content = await renderWidget(
          "shows the 'Add to cart' action on the product view",
        );
        expect(
          content,
          contains("expect(find.text('Add to cart'), findsOneWidget);"),
        );
        expect(content, isNot(contains('_RouteRecorder')));
        expect(
          content,
          contains("// scenario-assertions: presence(\"Add to cart\")"),
        );
      },
    );
  });

  group('zfa tdd view: taxonomy-aware composition', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: '096-finder-taxonomy');
    });

    tearDown(() => fx.dispose());

    /// Register a widget behavior whose subject is a gen-shaped stub.
    Future<void> seedWidgetStub(String id, String description) async {
      await fx.registerBehavior(
        id: id,
        description: description,
        writeTestFile: false,
      );
      final subject = File(fx.subjectPathOf(id));
      await subject.parent.create(recursive: true);
      await subject.writeAsString('''
library;

import 'package:flutter/material.dart';

/// Throws [UnimplementedError] until the real implementation lands.
Widget subject_${id.toLowerCase().replaceAll('-', '_')}() => throw UnimplementedError('$id');
''');
    }

    test('a route literal renders a navigation affordance, never the route '
        'name as display text (issue #964)', () async {
      await seedWidgetStub('A4', 'the app navigates to the route "deal_list"');
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'view',
        'A4',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('A4')).readAsString();
      expect(
        subject,
        isNot(contains("\n            Text('deal_list'),")),
        reason:
            'rendering the route name as a BARE Column child (findable '
            'display text) was the certified lie of issue #964; it may '
            'only appear as the labeled navigation affordance',
      );
      expect(subject, contains('ElevatedButton('));
      expect(subject, contains("child: Text('deal_list')"));
    });

    test('an absence literal renders nothing (rendering it would '
        'honestly fail the paired absence assertion)', () async {
      await seedWidgetStub(
        'A3',
        'the error banner hides "An error occurred" after a retry',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'view',
        'A3',
        '--project',
        fx.root.path,
      ]);
      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('A3')).readAsString();
      expect(subject, isNot(contains("Text('An error occurred')")));
      // No assertions rendered anything → the behavior-id marker text
      // keeps the view traceable.
      expect(subject, contains("Text('A3')"));
    });

    test(
      'a presence literal still renders its Text (issue #912 shape)',
      () async {
        await seedWidgetStub(
          'A1',
          "shows the 'Welcome back' message on the login view",
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'view',
          'A1',
          '--project',
          fx.root.path,
        ]);
        expect(exitCode, 0, reason: 'out: $out');
        final subject = await File(fx.subjectPathOf('A1')).readAsString();
        expect(subject, contains("Text('Welcome back')"));
      },
    );
  });

  group('zfa tdd verify-red: the kind gate (issue #964 proposal 3)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: '096-finder-taxonomy');
      final spy = await fx.writeSpyScript(
        'single',
        output: failingTranscript,
        exit: '1',
      );
      await fx.rewriteProfile(singleTemplate: spy, suiteTemplate: spy);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    /// Register a behavior whose test file is a WIDGET test in the
    /// OLD (pre-#964) style: the description header + testWidgets shape,
    /// presence-of-text assertion only.
    Future<void> registerWidgetBehavior({
      required String id,
      required String description,
      required String testContent,
    }) async {
      await fx.registerBehavior(
        id: id,
        description: description,
        writeTestFile: false,
      );
      final testFile = File(fx.testPathOf(id));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString(testContent);
    }

    test('an old-style presence-only navigation test is REFUSED '
        '(kind-mismatch, no evidence)', () async {
      await registerWidgetBehavior(
        id: 'A4',
        description: 'the app navigates to the route "deal_list"',
        testContent: '''
// GENERATED TEST — pre-taxonomy shape.
//
// kind: widget
// description: the app navigates to the route "deal_list"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A4', () {
    testWidgets('A4 — navigates', (tester) async {
      expect(find.text('deal_list'), findsOneWidget);
    });
  });
}
''',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        'A4',
      ]);
      expect(
        out,
        contains(
          'verify-red: behavior=A4 classification=kind-mismatch '
          'certified=false feature=${fx.featureName}',
        ),
        reason: 'out: $out',
      );
      expect(out, contains('route-outcome'));
      expect(exitCode, isNot(0));
      // The certified lie must never land in the ledger.
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    });

    test('a taxonomy-generated navigation test still certifies', () async {
      await registerWidgetBehavior(
        id: 'A4',
        description: 'the app navigates to the route "deal_list"',
        testContent: '''
// GENERATED TEST.
//
// kind: widget
// scenario-assertions: route-outcome("deal_list")
// description: the app navigates to the route "deal_list"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RouteRecorder extends NavigatorObserver {
  final List<String?> pushedNames = <String?>[];

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    pushedNames.add(route.settings.name);
  }
}

void main() {
  group('A4', () {
    testWidgets('A4 — navigates', (tester) async {
      final observer = _RouteRecorder();
      expect(observer.pushedNames, contains('deal_list'),
          reason: 'the scenario asserts navigation');
    });
  });
}
''',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        'A4',
      ]);
      expect(
        out,
        contains(
          'verify-red: behavior=A4 classification=assertion '
          'certified=true feature=${fx.featureName}',
        ),
        reason: 'out: $out',
      );
      expect(exitCode, 0);
    });

    test(
      'a scaffolded navigation test keeps certifying its bootstrap red',
      () async {
        await registerWidgetBehavior(
          id: 'A5',
          description: 'the app navigates to the route "deal_list"',
          testContent: '''
// GENERATED TEST.
//
// kind: widget
// description: the app navigates to the route "deal_list"
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A5', () {
    testWidgets('A5 — scaffolded', (tester) async {
      // zfa:tdd: scaffolded — placeholder finders only.
      expect(find.byWidget(SizedBox()), findsOneWidget);
    });
  });
}
''',
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'verify-red',
          '--project',
          fx.root.path,
          'A5',
        ]);
        expect(
          out,
          contains('certified=true'),
          reason:
              'scaffolded tests are already excluded from green accounting; '
              'their reds stay the bootstrap honest red — out: $out',
        );
        expect(exitCode, 0);
      },
    );

    test('a presence scenario with a presence test still certifies '
        '(no behavior change for #912 tests)', () async {
      await registerWidgetBehavior(
        id: 'A1',
        description: "shows the 'Add to cart' action on the product view",
        testContent: '''
// GENERATED TEST.
//
// kind: widget
// description: shows the 'Add to cart' action on the product view
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A1', () {
    testWidgets('A1 — presence', (tester) async {
      expect(find.text('Add to cart'), findsOneWidget);
    });
  });
}
''',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'verify-red',
        '--project',
        fx.root.path,
        'A1',
      ]);
      expect(
        out,
        contains('classification=assertion certified=true'),
        reason: 'out: $out',
      );
      expect(exitCode, 0);
    });
  });
}
