// HAND-WRITTEN TEST — the widget lane refused to scaffold A1 (issue #938:
// this repo is pure Dart and cannot declare zuraffa_ui, the Flutter host
// the widget lane boots). The behavior's substance is proven at the
// emission level through the A3-style acceptance shape instead: attestation
// header, real outcome assertion, no vacuous-guard marker (issues #1411,
// #1488).
//
// behavior_id: A1
// source_criterion: AC-1
// description: the emitted GoRouter installs an `errorBuilder` that renders a placeholder and a runtime empty-table fallback.
// zfa:tdd: A1:hand — hand step completed before first red certification (issue #1411)
library;

import 'package:test/test.dart';
import 'package:zuraffa/tdd/zero-route-gorouter-launch/a1_subject.dart'
    as subject;

void main() {
  group('A1 (AC-1)', () {
    test('A1 — the emitted GoRouter installs an `errorBuilder` that renders a '
        'placeholder and a runtime empty-table fallback.', () {
      final result = (() {
        try {
          return subject.subject_a1();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
      // Hand-step assertion (issue #1488 remedy): the bare variant (the
      // skin-audit variant is A3's surface) installs the errorBuilder and
      // the empty-table fallback, with the placeholder built from the
      // material types the file imports (issue #1673).
      expect(result, isA<String>());
      final emitted = result as String;
      expect(emitted, contains('errorBuilder: (context, state)'));
      expect(emitted, contains('getAllRoutes().isEmpty'));
      expect(emitted, contains('ZfaDayZeroPlaceholder'));
      expect(emitted, contains("import 'package:flutter/material.dart';"));
    });
  });
}
