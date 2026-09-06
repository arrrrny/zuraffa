// GENERATED TEST — `zfa tdd gen A5` (spec 044-test-tdd-generation).
//
// behavior_id: A5
// source_criterion: AC-5
// kind: widget
// i18n: slang test shell, base locale 'en' pinned; keyed surfaces resolve (issue #965)
// scenario-assertions: absence("t.auth.error")
// description: the 'Sign in failed' banner is not shown
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
import 'package:example/tdd/004-login-ui/a5_subject.dart' as subject;

void main() {
  group('A5 (AC-5)', () {
    testWidgets('A5 — the \'Sign in failed\' banner is not shown', (
      tester,
    ) async {
      // Honest-red capture + secondary guard (issue #959): call the
      // view-builder OUTSIDE pumpWidget so a subject that still throws
      // UnimplementedError lands in the expect below (an assertion
      // failure) instead of escaping the pump as a runner error (issue
      // #830 widget failure taxonomy). With the inert stub this passes
      // and the authored finders below are the primary red surface.
      final Object? built = (() {
        try {
          return subject.subject_a5();
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
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
      await tester.pumpAndSettle();
      // PRIMARY red surface (issue #959 + issue #964 taxonomy):
      // verb-matched authored finders derived from the scenario
      // description (issue #912 defect 3) execute after the pump and
      // fail against the inert stub's empty view — red is certified on
      // these assertions, never a placeholder a bare SizedBox() would
      // satisfy, never a route outcome flattened into presence-of-text.
      // The signIn anchor keeps the pass honest: find.byWidget(view)
      // mounts the widget under test itself, so absence assertions alone
      // would let an empty view through (CodeRabbit review, PR #1219).
      expect(find.text(t.auth.signIn), findsOneWidget);
      expect(find.text(t.auth.error), findsNothing);
      expect(find.byWidget(view), findsOneWidget);
    });
  });
}
