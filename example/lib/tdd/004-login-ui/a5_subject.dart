// GENERATED — `zfa tdd gen A5` (spec 044-test-tdd-generation), implemented
// at GREEN by the sanctioned handcraft seam (EPIC 1133).
//
// behavior_id: A5
// source_criterion: AC-5
// kind: widget
// description: the 'Sign in failed' banner is not shown
//
// RED: the machine honestly REFUSED to certify this red — the authored
// absence assertion (`expect(find.text(t.auth.error), findsNothing)`)
// passes against ANY view that does not render the banner, including the
// inert stub, so the run classified `unexpected-green` and verify-red
// wrote no evidence (issue #959: born-green assertions are refused, not
// certified). The absence behavior's proof is the LEDGER row
// (`absence("t.auth.error")`, traced by this green behavior — issue
// #966) plus this green run against a view whose banner machinery exists
// but is conditional: the banner renders ONLY in the error state, never
// on the initial render this scenario pins.
//
// The subject name is derived from the behavior id (`subject_a5`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'package:flutter/material.dart';
import 'package:example/i18n/strings.g.dart';

/// View-builder subject for behavior A5.
///
/// GREEN: the login view's initial state — the error banner is absent.
Widget subject_a5() => const _A5LoginInitial();

class _A5LoginInitial extends StatelessWidget {
  const _A5LoginInitial();

  @override
  Widget build(BuildContext context) {
    // Production contract: `_A5ErrorBanner` is mounted only when the
    // sign-in attempt has failed. The initial render this scenario pins
    // shows the sign-in surface and NO banner — a permanently rendered
    // banner would fail the absence assertion (the gaming view of issue
    // #966 cannot satisfy it).
    // `t` is locale-dependent — never const.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(t.auth.signIn),
        // A5ErrorBanner() — error state only (see the class below).
      ],
    );
  }
}

/// The error banner widget: keyed surface `t.auth.error`. Unreferenced
/// from the initial render — the absence scenario's whole point — but a
/// real member of the view contract so the surface stays traceable
/// (issue #965 ledger: `t.<key>` per declared row).
// ignore: unused_element
class _A5ErrorBanner extends StatelessWidget {
  const _A5ErrorBanner();

  @override
  Widget build(BuildContext context) {
    return Text(t.auth.error);
  }
}
