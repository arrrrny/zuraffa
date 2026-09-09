// Issue #1377 — the flagship fixture `example/specs/004-login-ui` could
// not go engine-green: FR-001 carried no `traces:` line to a declared
// Layer Contracts row, so its unit behavior U1 was fallback-routed and
// make correctly refused the guard-only test vacuous-green (issues
// #1259/#1308). This pin locks the migrated fixture: FR-001 traces to
// the declared `adaptive_layouts` row.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final spec = File('example/specs/004-login-ui/spec.md');

  test('B1: FR-001 traces to a declared Layer Contracts row', () {
    expect(spec.existsSync(), isTrue,
        reason: 'example/specs/004-login-ui is the flagship fixture');
    final source = spec.readAsStringSync();

    final fr001 = RegExp(
      r'- \*\*FR-001\*\*:.*?(?=\n- \*\*FR-|\n## )',
      dotAll: true,
    ).firstMatch(source);
    expect(fr001, isNotNull, reason: 'FR-001 exists in the fixture spec');

    expect(
      fr001!.group(0),
      contains('traces:'),
      reason: 'the #1377 grammar migration: FR-001 declares the contract '
          'row its unit behavior routes to',
    );
  });

  test('B2: the traced row is declared in the Layer Contracts section',
      () {
    final source = spec.readAsStringSync();
    final fr001 = RegExp(
      r'- \*\*FR-001\*\*:.*?(?=\n- \*\*FR-|\n## )',
      dotAll: true,
    ).firstMatch(source)!;
    final traceMatch =
        RegExp(r'traces:\s*(\S+)').firstMatch(fr001.group(0) ?? '')!;
    final row = traceMatch.group(1)!;

    expect(source, contains('`$row`'),
        reason: 'the traced row "$row" is declared in the Layer Contracts '
            'section — no dangling trace');
  });
}
