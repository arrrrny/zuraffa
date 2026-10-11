// Issue #1112 — the generated per-view seam: `zfa make --skin` emits
// one debugTap<PascalAnchor>() per zfa: anchor declared on the view,
// so the VM-service function lookup is just debugTap<PascalAnchor>().
library;

import 'package:code_builder/code_builder.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/view/builders/view_class_builder.dart';

void main() {
  const builder = ViewClassBuilder();

  ViewClassSpec spec({List<String> anchors = const []}) => ViewClassSpec(
    viewName: 'LoginView',
    controllerName: 'LoginController',
    presenterName: 'LoginPresenter',
    entityName: 'Login',
    repoFields: const [],
    routeFields: const [],
    repoPresenterArgs: const [],
    initialMethodCall: Block((b) => b),
    imports: const ['package:flutter/material.dart'],
    withState: false,
    withSkinAudit: true,
    anchors: anchors,
  );

  group('issue #1112 — per-view debugTap<PascalAnchor>() seam', () {
    test('one function per declared anchor (kebab → Pascal case)', () {
      final src = builder.build(
        spec(anchors: const ['signin-guest', 'log-out']),
      );
      expect(
        src,
        contains(
          "Future<TapResult> debugTapSigninGuest() => debugTapAnchor('zfa:signin-guest')",
        ),
      );
      expect(
        src,
        contains(
          "Future<TapResult> debugTapLogOut() => debugTapAnchor('zfa:log-out')",
        ),
      );
    });

    test('each anchor declares its contract row (anchorExists)', () {
      final src = builder.build(spec(anchors: const ['signin-guest']));
      expect(src, contains('SkinContractRow.anchorExists('));
      expect(src, contains("anchor: 'signin-guest'"));
    });

    test('bare-word anchors keep the issue naming (debugTapGuest)', () {
      final src = builder.build(spec(anchors: const ['guest']));
      expect(
        src,
        contains(
          "Future<TapResult> debugTapGuest() => debugTapAnchor('zfa:guest')",
        ),
      );
    });

    test(
      'duplicate anchors collapse to one function (idempotent emission)',
      () {
        final src = builder.build(
          spec(anchors: const ['signin-guest', 'signin-guest']),
        );
        expect('debugTapSigninGuest'.allMatches(src).length, 1);
      },
    );

    test('without anchors the view carries NO driver tokens (byte-compat)', () {
      final src = builder.build(spec(anchors: const []));
      expect(src, isNot(contains('debugTap')));
      expect(src, isNot(contains('TapResult')));
    });
  });
}
