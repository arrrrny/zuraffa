// GENERATED TEST — `zfa tdd gen A7` (spec 044-test-tdd-generation).
//
// behavior_id: A7
// source_criterion: AC-7
// kind: widget
// i18n: slang test shell, base locale 'en' pinned; keyed surfaces resolve (issue #965)
// scenario-assertions: sequence, presence("t.auth.working"), route-outcome("deal_list")
// description: while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'
//
// This is a WIDGET test (bug #830): it boots the feature view through
// the subject's view-builder contract, pumps it inside a MaterialApp
// shell, and asserts the acceptance scenario through verb-matched
// assertions (issue #964 finder-kind taxonomy: shows/renders → presence,
// navigates → route outcome via the recorded pushed routes, hides/not
// shown → absence, disables/enables → enabled state; a while/in-flight
// sequence scenario is marked scaffolded). RED SURFACE (issue #959): the
// stub is inert (SizedBox.shrink), so the guard passes, the pump runs,
// and these verb-matched authored finders fail against the empty view —
// red is certified on the assertions, never at the guard. The
// UnimplementedError capture below is the SECONDARY guard: if a subject
// still throws, the error lands in the guard assertion instead of
// escaping the pump (classified runner/compile, not red — issue #830
// widget failure taxonomy). Widget tests run on the flutter profile's
// slower tier; golden baselines are committed per platform under
// test/tdd/goldens/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/i18n/strings.g.dart';
import 'package:example/tdd/004-login-ui/a7_subject.dart' as subject;

void main() {
  group('A7 (AC-7)', () {
    testWidgets(
      'A7 — while the sign-in request is in flight the app shows \'Signing in…\' and then the app navigates to the route \'deal_list\'',
      (tester) async {
        // Honest-red capture + secondary guard (issue #959): call the
        // view-builder OUTSIDE pumpWidget so a subject that still throws
        // UnimplementedError lands in the expect below (an assertion
        // failure) instead of escaping the pump as a runner error (issue
        // #830 widget failure taxonomy). With the inert stub this passes
        // and the authored finders below are the primary red surface.
        // Route-outcome recording (issue #964): the scenario asserts
        // navigation, so pushed ROUTES are observed — never the
        // route name rendered as on-screen text.
        final observer = _RouteRecorder();
        final Object? built = (() {
          try {
            return subject.subject_a7();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(built, isNot(isA<UnimplementedError>()));
        final view = built! as Widget;
        // Boot the view inside an app shell so Theme.of / ShadTheme.of /
        // Navigator / MediaQuery lookups resolve (issue #830 remediation 2;
        // shell configurable per issue #912 defect 2).
        // Slang test shell (issue #965): the base locale is pinned so
        // the resolved keys render the anchor copy — a copy edit to
        // the EN string can never break green; a missing key fails
        // RED honestly (the fallback is the base copy, not a lie).
        LocaleSettings.setLocaleRaw('en');
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: <NavigatorObserver>[observer],
            home: Scaffold(body: view),
          ),
        );
        await tester.pumpAndSettle();
        // PRIMARY red surface (issue #959 + issue #964 taxonomy):
        // verb-matched authored finders derived from the scenario
        // description (issue #912 defect 3) execute after the pump and
        // fail against the inert stub's empty view — red is certified on
        // these assertions, never a placeholder a bare SizedBox() would
        // satisfy, never a route outcome flattened into presence-of-text.
        //
        // SEQUENCE hand implementation (EPIC 1133, per this test's own
        // scaffold instruction): the single-pump template cannot assert an
        // in-flight state machine honestly, so the scaffolded placeholder
        // block was replaced with the machine chain —
        //   act → pump the intermediate state → assert → settle →
        //   assert the final state.
        // The single-pump shape this replaces would have required the
        // working surface AND the pushed route to coexist after ONE
        // settle — mutually exclusive for an honest view (the pushed route
        // covers the home view, so the presence finder would honestly
        // fail). The chain asserts each kind in its own phase instead.
        //
        // act: submit the form (the scenario's in-flight begins here).
        await tester.tap(find.widgetWithText(ElevatedButton, t.auth.signIn));
        await tester.pump();
        // assert the INTERMEDIATE state: while the request is in flight,
        // the working surface renders through its resolved key.
        expect(
          find.text(t.auth.working),
          findsOneWidget,
          reason:
              'the scenario asserts the working surface renders while '
              'the sign-in request is in flight',
        );
        // resolve → assert the FINAL state: the request resolves and the
        // flow navigates — the route outcome, observed by the recorder.
        await tester.pumpAndSettle();
        expect(
          observer.pushedNames,
          contains('deal_list'),
          reason:
              'the scenario asserts navigation to route deal_list; a rendered string is not a navigation',
        );
      },
    );
    testWidgets(
      'A7 — expansion locale de renders every keyed surface (issue #965)',
      (tester) async {
        // Expansion tier (issue #965, optional): pump the expansion locale —
        // de strings run ~30% longer, catching overflow assumptions before
        // goldens do. Assertions stay on the RESOLVED keys.
        LocaleSettings.setLocaleRaw('de');
        final Object? built = (() {
          try {
            return subject.subject_a7();
          } on UnimplementedError catch (error) {
            return error;
          }
        })();
        expect(built, isNot(isA<UnimplementedError>()));
        final view = built! as Widget;
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
        await tester.pumpAndSettle();
        // The keyed surface `t.auth.working` renders in the IN-FLIGHT state
        // (this behavior is a sequence), so the expansion pump includes the
        // act step that enters it — the German pump then proves the LONGER
        // expansion copy (~130%+ of the EN anchor) renders and the layout
        // holds under it (issue #965 optional tier).
        await tester.tap(find.widgetWithText(ElevatedButton, t.auth.signIn));
        await tester.pump();
        expect(
          find.text(t.auth.working),
          findsOneWidget,
          reason: 'the keyed surface t.auth.working must render under de',
        );
        await tester.pumpAndSettle();
      },
    );
  });
}

/// Records pushed route names so route-outcome assertions (issue #964)
/// observe real navigation — the scenario's green measures the ROUTE
/// outcome, not the route name rendered as display text.
class _RouteRecorder extends NavigatorObserver {
  final List<String?> pushedNames = <String?>[];

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    pushedNames.add(route.settings.name);
  }
}
