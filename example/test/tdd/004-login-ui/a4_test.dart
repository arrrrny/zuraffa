// GENERATED TEST — `zfa tdd gen A4` (spec 044-test-tdd-generation).
//
// behavior_id: A4
// source_criterion: AC-4
// kind: widget
// scenario-assertions: route-outcome("deal_list")
// description: the app navigates to the route 'deal_list'
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
import 'package:example/tdd/004-login-ui/a4_subject.dart' as subject;

void main() {
  group('A4 (AC-4)', () {
    testWidgets('A4 — the app navigates to the route \'deal_list\'', (
      tester,
    ) async {
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
          return subject.subject_a4();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(built, isNot(isA<UnimplementedError>()));
      final view = built! as Widget;
      // Boot the view inside an app shell so Theme.of / ShadTheme.of /
      // Navigator / MediaQuery lookups resolve (issue #830 remediation 2;
      // shell configurable per issue #912 defect 2).
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
      expect(
        observer.pushedNames,
        contains('deal_list'),
        reason:
            'the scenario asserts navigation to route deal_list; a rendered string is not a navigation',
      );
    });
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
