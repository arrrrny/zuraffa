// GENERATED — `zfa tdd gen A3` (spec 044-test-tdd-generation), implemented
// at GREEN by the sanctioned handcraft seam (EPIC 1133).
//
// behavior_id: A3
// source_criterion: AC-3
// kind: widget
// description: the app shows 'Sign in'
//
// RED was certified against the inert stub this file replaced (cycle-log
// `Cycle: A3 (red)`): the authored presence finder
// `expect(find.text(t.auth.signIn), findsOneWidget)` failed against the
// empty view. The implementation below renders the sign-in surface
// through its DECLARED i18n key (issue #965) — `t.auth.signIn`, never the
// pinned EN literal — so a copy edit to the EN string cannot break green
// and a missing key fails red honestly.
//
// The subject name is derived from the behavior id (`subject_a3`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:flutter/material.dart';
import 'package:example/i18n/strings.g.dart';

/// View-builder subject for behavior A3.
///
/// GREEN: renders the sign-in surface through the resolved slang key.
Widget subject_a3() => const _A3SignInSurface();

class _A3SignInSurface extends StatelessWidget {
  const _A3SignInSurface();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // No decorative Key: every literal in the subject must be
        // observable by the paired test (the mutation audit rejects
        // unobservable surface — EPIC 1133 green evidence).
        Text(t.auth.signIn),
      ],
    );
  }
}
