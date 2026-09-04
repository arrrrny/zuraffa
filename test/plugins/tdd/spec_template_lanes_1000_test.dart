// Issue #1000 (FR-012): the spec template — the file
// `.specify/templates/spec-template.md` that `create-new-feature.sh`
// copies into every new spec — documents the `## Lanes` grammar with a
// worked example, so new specs are authored against the lane contract.
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../helpers/project_root.dart';

void main() async {
  final repoRoot = await findProjectRoot();
  final template = File(
    '$repoRoot/.specify/templates/spec-template.md',
  ).readAsStringSync();

  group('issue #1000 — the spec template carries the Lanes grammar', () {
    test('the ## Lanes section documents CORE/SKIN/BOTH, behaviors (ranges '
        'and annotations), flutter_allowed, and adaptive_slots', () {
      expect(
        RegExp(
          r'^#{1,6}\s+lanes\b',
          multiLine: true,
          caseSensitive: false,
        ).hasMatch(template),
        isTrue,
        reason: 'the section heading is present',
      );
      for (final documented in [
        '- lane: CORE',
        '- lane: SKIN',
        '- lane: BOTH',
        'behaviors: [A1, A2, U1-U6]',
        'behaviors: [W1-W4]',
        'behaviors: [A3 (acceptance: navigates to deal_list)]',
        'flutter_allowed: false',
        'flutter_allowed: true',
        'flutter_allowed: conditionally',
        'adaptive_slots: [mobile, ios, android, macos]',
      ]) {
        expect(
          template.contains(documented),
          isTrue,
          reason: 'the template documents `$documented`',
        );
      }
    });
  });
}
