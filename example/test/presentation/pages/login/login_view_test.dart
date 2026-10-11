// Paired widget test for W1 — the login view fills every declared
// platform slot (issue #1005: the hand-written skin's contract test).
//
// behavior_id: W1
// source_criterion: FR-001
// kind: widget
// description: the login view fills every declared platform slot
//
// This is the WIDGET pair the skin cycle boots (bug #830 / issue
// #1005): the view-builder contract (loginView) is called OUTSIDE
// pumpWidget first so a subject that still throws UnimplementedError
// lands in the expect below instead of escaping the pump (the issue
// #959 honest-red capture); then the view is pumped across the
// declared platform matrix — mobile (phone width), ios, android,
// macos — asserting each slot's branch rendered. The view's own
// SkinEvent lines (skin-event: behavior=W1 slot=<slot>) stream into
// the transcript the run-skin cycle digests.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/src/presentation/pages/login/login_view.dart'
    as subject;

void main() {
  testWidgets('W1 — the login view fills every declared platform slot', (
    tester,
  ) async {
    // Honest-red capture + secondary guard (issue #959): call the
    // view-builder OUTSIDE pumpWidget so a subject that still throws
    // UnimplementedError lands in the expect below as an assertion
    // failure, not a runner error.
    final built = (() {
      try {
        return subject.loginView();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(built, isNot(isA<UnimplementedError>()));
    final view = built as Widget;

    // -- mobile: a phone-width surface resolves the mobile slot on
    //    every platform.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: view));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('login-slot-mobile')),
      findsOneWidget,
      reason: 'phone width resolves the mobile slot branch',
    );
    expect(find.byKey(const Key('login-email')), findsOneWidget);

    // -- ios: a wide surface on the iOS platform resolves the ios slot
    //    (the home-indicator SafeArea contract, #1004).
    tester.view.physicalSize = const Size(900, 700);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(MaterialApp(home: view));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-slot-ios')), findsOneWidget);
    expect(
      find.byType(SafeArea),
      findsWidgets,
      reason: 'the ios slot requires the home-indicator safe area',
    );

    // -- android: a wide surface on the android platform.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(MaterialApp(home: view));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-slot-android')), findsOneWidget);

    // -- macos: a wide surface on the macOS platform resolves the macos
    //    slot (the trailing title-bar alignment contract, #1004).
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(MaterialApp(home: view));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-slot-macos')), findsOneWidget);

    // Reset the foundation debug variable INSIDE the body — the
    // framework's invariant check runs after the body completes.
    debugDefaultTargetPlatformOverride = null;

    // The declared slot set is covered by the four per-slot asserts
    // above (one per pump position of the platform matrix); the
    // submit affordance is live in every slot branch.
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
  });
}
