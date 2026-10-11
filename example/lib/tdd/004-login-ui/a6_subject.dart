// GENERATED — `zfa tdd gen A6` (spec 044-test-tdd-generation), implemented
// at GREEN by the sanctioned handcraft seam (EPIC 1133).
//
// behavior_id: A6
// source_criterion: AC-6
// kind: widget
// description: the 'Sign in' button is disabled
//
// RED was certified against the inert stub this file replaced (cycle-log
// `Cycle: A6 (red)`): the authored enabled-state assertion failed at its
// first gate — `find.widgetWithText(ElevatedButton, t.auth.signIn)`
// found nothing on the empty view, so the control's `onPressed`
// null-ness was never even reached. The implementation below renders the
// labeled control with `onPressed: null` — the empty-form validation
// state the scenario pins (issue #964: `disables` → enabled-state, a
// widget ATTRIBUTE, never a presence row).
//
// The subject name is derived from the behavior id (`subject_a6`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:flutter/material.dart';
import 'package:example/i18n/strings.g.dart';

/// View-builder subject for behavior A6.
///
/// GREEN: the sign-in control in the disabled (empty-form) state.
Widget subject_a6() => const _A6LoginForm();

class _A6LoginForm extends StatelessWidget {
  const _A6LoginForm();

  @override
  Widget build(BuildContext context) {
    // Empty form: validation keeps the submit control disabled. The
    // enabled-state assertion reads onPressed null-ness — presence of the
    // control alone proves nothing (issue #966 state rows).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ElevatedButton(onPressed: null, child: Text(t.auth.signIn)),
      ],
    );
  }
}
