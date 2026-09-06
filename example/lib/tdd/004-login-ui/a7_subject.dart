// GENERATED — `zfa tdd gen A7` (spec 044-test-tdd-generation), implemented
// at GREEN by the sanctioned handcraft seam (EPIC 1133).
//
// behavior_id: A7
// source_criterion: AC-7
// kind: widget
// description: while the sign-in request is in flight the app shows
//   'Signing in…' and then the app navigates to the route 'deal_list'
//
// The scenario is a SEQUENCE (issue #964: `while … in flight` →
// interaction-chain), so the single-pump template scaffolded the test
// instead of silently flattening it to presence. The paired test now
// carries the hand-implemented act → assert-intermediate → resolve →
// assert-final chain, and this subject implements the state machine the
// chain referees:
//
//   tap (act) → submitting=true → `t.auth.working` renders (intermediate)
//   → the in-flight future resolves → push named `deal_list` (final).
//
// RED was certified against the inert stub (cycle-log `Cycle: A7 (red)`):
// the authored `t.auth.working` presence finder failed against the empty
// view while the test was still scaffolded.
//
// The subject name is derived from the behavior id (`subject_a7`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:flutter/material.dart';
import 'package:example/i18n/strings.g.dart';

/// View-builder subject for behavior A7.
///
/// GREEN: the sign-in flow's state machine — tap → working surface →
/// named `deal_list` route push.
Widget subject_a7() => const _A7SignInFlow();

class _A7SignInFlow extends StatefulWidget {
  const _A7SignInFlow();

  @override
  State<_A7SignInFlow> createState() => _A7SignInFlowState();
}

class _A7SignInFlowState extends State<_A7SignInFlow> {
  bool _submitting = false;

  void _submit() {
    if (_submitting) return;
    setState(() => _submitting = true);
    // The in-flight request resolves, then the flow navigates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          settings: const RouteSettings(name: 'deal_list'),
          pageBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_submitting) Text(t.auth.working),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: Text(t.auth.signIn),
        ),
      ],
    );
  }
}
