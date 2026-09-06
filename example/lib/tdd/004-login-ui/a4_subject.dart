// GENERATED — `zfa tdd gen A4` (spec 044-test-tdd-generation), implemented
// at GREEN by the sanctioned handcraft seam (EPIC 1133).
//
// behavior_id: A4
// source_criterion: AC-4
// kind: widget
// description: the app navigates to the route 'deal_list'
//
// RED was certified against the inert stub this file replaced (cycle-log
// `Cycle: A4 (red)`): the authored route-outcome assertion
// `expect(observer.pushedNames, contains('deal_list'))` observed only the
// initial route ('/') — a rendered string is not a navigation. The
// implementation below performs the REAL route push the scenario
// declares: the completed sign-in pushes the named `deal_list` route, so
// the recording NavigatorObserver sees the route outcome (issue #964),
// not a Text widget bearing the route's name.
//
// The subject name is derived from the behavior id (`subject_a4`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior A4.
///
/// GREEN: pushes the named `deal_list` route once on arrival — the
/// scenario's Given is the completed sign-in.
Widget subject_a4() => const _A4CompletedSignIn();

class _A4CompletedSignIn extends StatefulWidget {
  const _A4CompletedSignIn();

  @override
  State<_A4CompletedSignIn> createState() => _A4CompletedSignInState();
}

class _A4CompletedSignInState extends State<_A4CompletedSignIn> {
  @override
  void initState() {
    super.initState();
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
    return const Scaffold(body: SizedBox.shrink());
  }
}
